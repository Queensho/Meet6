import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { ContentSafetyService } from './content-safety.service';
import { InfrastructureService } from './infrastructure.service';

@Injectable()
export class ReportService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly safety: ContentSafetyService,
  ) {}

  async submit(
    userId: string,
    targetUserId: string | number,
    reasonInput: string,
    detail?: string,
    roomId?: string,
    matchId?: string,
  ) {
    const reason = reasonInput.trim();
    const cleanDetail = detail?.trim() || null;
    const cleanRoomId = roomId?.trim() || null;
    let cleanMatchId = matchId?.trim() || null;

    if (!reason) throw new BadRequestException('Şikâyet nedeni gerekli.');
    if (String(userId) === String(targetUserId)) {
      throw new BadRequestException('Kendini şikâyet edemezsin.');
    }
    if (cleanRoomId && cleanMatchId) {
      throw new BadRequestException('Şikâyet aynı anda hem oda hem özel sohbet içeremez.');
    }

    const target = await this.infra.db.query<{ exists: boolean }>(
      'select exists(select 1 from users where id=$1) as exists',
      [targetUserId],
    );
    if (!target.rows[0]?.exists) throw new NotFoundException('Kullanıcı bulunamadı.');

    // Older app builds did not send matchId from the private chat report dialog.
    // If the pair currently has an active match, attach it automatically so the
    // moderation panel still receives the private-chat evidence context.
    if (!cleanRoomId && !cleanMatchId) {
      const activeMatch = await this.infra.db.query<{ id: string }>(
        `select id::text
         from matches
         where unmatched_at is null
           and least(user_a_id,user_b_id)=least($1::bigint,$2::bigint)
           and greatest(user_a_id,user_b_id)=greatest($1::bigint,$2::bigint)
         order by created_at desc
         limit 1`,
        [userId, targetUserId],
      );
      cleanMatchId = activeMatch.rows[0]?.id ?? null;
    }

    if (cleanRoomId) {
      const membership = await this.infra.db.query<{ count: string }>(
        `select count(distinct user_id)::text as count
         from room_members
         where room_id=$1 and user_id in ($2::bigint,$3::bigint)`,
        [cleanRoomId, userId, targetUserId],
      );
      if (Number(membership.rows[0]?.count ?? 0) !== 2) {
        throw new BadRequestException('Bu oda için şikâyet bağlantısı doğrulanamadı.');
      }
    }

    if (cleanMatchId) {
      const match = await this.infra.db.query<{ exists: boolean }>(
        `select exists(
           select 1 from matches
           where id=$1
             and least(user_a_id,user_b_id)=least($2::bigint,$3::bigint)
             and greatest(user_a_id,user_b_id)=greatest($2::bigint,$3::bigint)
         ) as exists`,
        [cleanMatchId, userId, targetUserId],
      );
      if (!match.rows[0]?.exists) {
        throw new BadRequestException('Bu özel sohbet için şikâyet bağlantısı doğrulanamadı.');
      }
    }

    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      const inserted = await client.query<{ id: string }>(
        `insert into reports(
           reporter_user_id, reported_user_id, room_id, match_id, reason, detail
         ) values($1,$2,$3,$4,$5,$6)
         returning id::text`,
        [userId, targetUserId, cleanRoomId, cleanMatchId, reason, cleanDetail],
      );
      const reportId = inserted.rows[0].id;

      if (cleanRoomId) {
        await client.query(
          `insert into report_evidence_messages(
             report_id, source_type, source_message_id, sender_user_id,
             body, message_created_at
           )
           select $1, 'room_message', snapshot.id, snapshot.sender_user_id,
                  snapshot.body, snapshot.created_at
           from (
             select m.id, m.sender_user_id, m.body, m.created_at
             from room_messages m
             where m.room_id=$2 and m.sender_user_id is not null
             order by m.id desc
             limit 60
           ) snapshot
           order by snapshot.id asc
           on conflict do nothing`,
          [reportId, cleanRoomId],
        );
      }

      if (cleanMatchId) {
        await client.query(
          `insert into report_evidence_messages(
             report_id, source_type, source_message_id, sender_user_id,
             body, message_created_at
           )
           select $1, 'private_message', snapshot.id, snapshot.sender_user_id,
                  snapshot.body, snapshot.created_at
           from (
             select m.id, m.sender_user_id, m.body, m.created_at
             from private_messages m
             where m.match_id=$2
             order by m.id desc
             limit 60
           ) snapshot
           order by snapshot.id asc
           on conflict do nothing`,
          [reportId, cleanMatchId],
        );
      }

      await client.query('commit');
      const triage = await this.safety
        .triageReport(reportId, targetUserId, reason)
        .catch((error) => {
          // A triage outage must never drop a user's report. The report remains
          // open and can still be reviewed manually.
          // eslint-disable-next-line no-console
          console.warn('Automated report triage failed', error);
          return null;
        });
      return { ok: true, reportId, triage };
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }
}
