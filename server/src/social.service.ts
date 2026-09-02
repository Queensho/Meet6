import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { UpdateSettingsDto } from './social.dto';

@Injectable()
export class SocialService {
  constructor(private readonly infra: InfrastructureService) {}

  private async assertActiveMatch(userId: string, matchId: string | number) {
    const result = await this.infra.db.query<{
      id: string;
      user_a_id: string;
      user_b_id: string;
    }>(
      `select id::text, user_a_id::text, user_b_id::text
       from matches
       where id=$1 and unmatched_at is null
         and (user_a_id=$2 or user_b_id=$2)`,
      [matchId, userId],
    );
    const match = result.rows[0];
    if (!match) throw new NotFoundException('Eşleşme bulunamadı.');
    return match;
  }

  async listMatches(userId: string) {
    const result = await this.infra.db.query(
      `select m.id::text as match_id,
              other.id::text as user_id,
              p.display_name,
              extract(year from age(current_date,p.birth_date))::int as age,
              p.gender, p.bio, p.city, p.country, p.profile_prompt, p.profile_answer,
              p.interests, p.photo_urls,
              m.created_at as matched_at,
              last_message.body as last_message,
              last_message.created_at as last_message_at,
              coalesce(unread.count,0)::int as unread_count
       from matches m
       join users other on other.id = case when m.user_a_id=$1 then m.user_b_id else m.user_a_id end
       join profiles p on p.user_id = other.id
       left join lateral (
         select pm.body, pm.created_at
         from private_messages pm
         where pm.match_id=m.id
         order by pm.id desc limit 1
       ) last_message on true
       left join lateral (
         select count(*)::int as count
         from private_messages pm
         where pm.match_id=m.id and pm.sender_user_id<>$1 and pm.read_at is null
       ) unread on true
       where m.unmatched_at is null and (m.user_a_id=$1 or m.user_b_id=$1)
       order by coalesce(last_message.created_at,m.created_at) desc`,
      [userId],
    );
    const unreadTotal = result.rows.reduce((sum, row: any) => sum + Number(row.unread_count ?? 0), 0);
    return { ok: true, matches: result.rows, unreadTotal };
  }

  async matchDetail(userId: string, matchId: string | number) {
    const match = await this.assertActiveMatch(userId, matchId);
    const otherId = match.user_a_id === String(userId) ? match.user_b_id : match.user_a_id;
    const result = await this.infra.db.query(
      `select u.id::text as user_id, p.display_name,
              extract(year from age(current_date,p.birth_date))::int as age,
              p.gender, p.bio, p.city, p.country,
              p.profile_prompt, p.profile_answer, p.interests, p.photo_urls,
              case when us.show_online=false then false
                   when u.last_seen_at is null then false
                   else u.last_seen_at > now()-interval '5 minutes' end as online
       from users u
       join profiles p on p.user_id=u.id
       left join user_settings us on us.user_id=u.id
       where u.id=$1`,
      [otherId],
    );
    if (!result.rows[0]) throw new NotFoundException('Profil bulunamadı.');
    return { ok: true, matchId: String(matchId), profile: result.rows[0] };
  }

  async privateMessages(userId: string, matchId: string | number, afterId = 0) {
    await this.assertActiveMatch(userId, matchId);
    const result = await this.infra.db.query(
      `select pm.id::text, pm.sender_user_id::text, pm.body, pm.created_at, pm.read_at
       from private_messages pm
       where pm.match_id=$1 and pm.id>$2
       order by pm.id asc
       limit 300`,
      [matchId, afterId],
    );
    return { ok: true, messages: result.rows };
  }

  async sendPrivateMessage(userId: string, matchId: string | number, bodyInput: string) {
    const body = bodyInput.trim();
    if (!body) throw new BadRequestException('Mesaj boş olamaz.');
    const match = await this.assertActiveMatch(userId, matchId);
    const otherId = match.user_a_id === String(userId) ? match.user_b_id : match.user_a_id;

    const blocked = await this.infra.db.query<{ exists: boolean }>(
      `select exists(
         select 1 from blocked_users
         where (blocker_user_id=$1 and blocked_user_id=$2)
            or (blocker_user_id=$2 and blocked_user_id=$1)
       ) as exists`,
      [userId, otherId],
    );
    if (blocked.rows[0]?.exists) throw new ForbiddenException('Bu kullanıcıyla mesajlaşamazsın.');

    const rateKey = `private-message:${userId}:${matchId}`;
    const allowed = await this.infra.redis.set(rateKey, '1', 'EX', 1, 'NX');
    if (!allowed) throw new BadRequestException('Çok hızlı mesaj gönderiyorsun.');

    const result = await this.infra.db.query(
      `insert into private_messages(match_id,sender_user_id,body)
       values($1,$2,$3)
       returning id::text, sender_user_id::text, body, created_at, read_at`,
      [matchId, userId, body],
    );
    const sender = await this.infra.db.query<{ display_name: string }>(
      'select display_name from profiles where user_id=$1',
      [userId],
    );
    await this.infra.db.query(
      `insert into notifications(user_id,type,title,body,data)
       values($1,'message',$2,$3,jsonb_build_object('matchId',$4))`,
      [otherId, sender.rows[0]?.display_name ?? 'Meet6', body.slice(0, 200), String(matchId)],
    );
    return { ok: true, message: result.rows[0] };
  }

  async markRead(userId: string, matchId: string | number) {
    await this.assertActiveMatch(userId, matchId);
    await this.infra.db.query(
      `update private_messages set read_at=coalesce(read_at,now())
       where match_id=$1 and sender_user_id<>$2 and read_at is null`,
      [matchId, userId],
    );
    return { ok: true };
  }

  async unmatch(userId: string, matchId: string | number) {
    await this.assertActiveMatch(userId, matchId);
    await this.infra.db.query(
      `update matches set unmatched_at=now()
       where id=$1 and unmatched_at is null`,
      [matchId],
    );
    return { ok: true };
  }

  async blocks(userId: string) {
    const result = await this.infra.db.query(
      `select b.blocked_user_id::text as user_id, b.created_at,
              p.display_name,
              extract(year from age(current_date,p.birth_date))::int as age,
              p.photo_urls
       from blocked_users b
       join profiles p on p.user_id=b.blocked_user_id
       where b.blocker_user_id=$1
       order by b.created_at desc`,
      [userId],
    );
    return { ok: true, blocked: result.rows };
  }

  async block(userId: string, targetUserId: string | number) {
    if (String(userId) === String(targetUserId)) throw new BadRequestException('Kendini engelleyemezsin.');
    const target = await this.infra.db.query<{ exists: boolean }>(
      'select exists(select 1 from users where id=$1) as exists',
      [targetUserId],
    );
    if (!target.rows[0]?.exists) throw new NotFoundException('Kullanıcı bulunamadı.');

    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query(
        `insert into blocked_users(blocker_user_id,blocked_user_id)
         values($1,$2) on conflict do nothing`,
        [userId, targetUserId],
      );
      await client.query(
        `update matches set unmatched_at=coalesce(unmatched_at,now())
         where unmatched_at is null
           and least(user_a_id,user_b_id)=least($1::bigint,$2::bigint)
           and greatest(user_a_id,user_b_id)=greatest($1::bigint,$2::bigint)`,
        [userId, targetUserId],
      );
      await client.query('delete from matchmaking_queue where user_id=$1', [userId]);
      await client.query('commit');
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
    return { ok: true };
  }

  async unblock(userId: string, targetUserId: string | number) {
    await this.infra.db.query(
      'delete from blocked_users where blocker_user_id=$1 and blocked_user_id=$2',
      [userId, targetUserId],
    );
    return { ok: true };
  }

  async report(
    userId: string,
    targetUserId: string | number,
    reasonInput: string,
    detail?: string,
    roomId?: string,
  ) {
    const reason = reasonInput.trim();
    if (!reason) throw new BadRequestException('Şikâyet nedeni gerekli.');
    if (String(userId) === String(targetUserId)) throw new BadRequestException('Kendini şikâyet edemezsin.');
    const target = await this.infra.db.query<{ exists: boolean }>(
      'select exists(select 1 from users where id=$1) as exists',
      [targetUserId],
    );
    if (!target.rows[0]?.exists) throw new NotFoundException('Kullanıcı bulunamadı.');
    await this.infra.db.query(
      `insert into reports(reporter_user_id,reported_user_id,room_id,reason,detail)
       values($1,$2,$3,$4,$5)`,
      [userId, targetUserId, roomId || null, reason, detail?.trim() || null],
    );
    return { ok: true };
  }

  async getSettings(userId: string) {
    await this.infra.db.query(
      `insert into user_settings(user_id) values($1) on conflict do nothing`,
      [userId],
    );
    const result = await this.infra.db.query(
      `select notifications_enabled, room_reminders, show_online, precise_location, vibration
       from user_settings where user_id=$1`,
      [userId],
    );
    return { ok: true, settings: result.rows[0] };
  }

  async updateSettings(userId: string, body: UpdateSettingsDto) {
    await this.infra.db.query(
      `insert into user_settings(
         user_id,notifications_enabled,room_reminders,show_online,precise_location,vibration
       ) values(
         $1,coalesce($2,true),coalesce($3,true),coalesce($4,true),coalesce($5,false),coalesce($6,true)
       )
       on conflict(user_id) do update set
         notifications_enabled=coalesce($2,user_settings.notifications_enabled),
         room_reminders=coalesce($3,user_settings.room_reminders),
         show_online=coalesce($4,user_settings.show_online),
         precise_location=coalesce($5,user_settings.precise_location),
         vibration=coalesce($6,user_settings.vibration),
         updated_at=now()`,
      [
        userId,
        body.notificationsEnabled ?? null,
        body.roomReminders ?? null,
        body.showOnline ?? null,
        body.preciseLocation ?? null,
        body.vibration ?? null,
      ],
    );
    return this.getSettings(userId);
  }

  async notifications(userId: string) {
    const result = await this.infra.db.query(
      `select id::text,type,title,body,data,read_at,created_at
       from notifications where user_id=$1
       order by created_at desc limit 100`,
      [userId],
    );
    const unread = result.rows.filter((row: any) => row.read_at == null).length;
    return { ok: true, notifications: result.rows, unread };
  }

  async markNotificationsRead(userId: string) {
    await this.infra.db.query(
      'update notifications set read_at=coalesce(read_at,now()) where user_id=$1 and read_at is null',
      [userId],
    );
    return { ok: true };
  }
}
