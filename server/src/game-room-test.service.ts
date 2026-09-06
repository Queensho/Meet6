import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';

@Injectable()
export class GameRoomTestService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
  ) {}

  private testUserIds(currentUserId: string) {
    if (process.env.GAME_ROOM_TEST_ENABLED !== 'true') {
      throw new ForbiddenException('Mini oyun test odası sunucuda kapalı.');
    }

    const ids = (process.env.GAME_ROOM_TEST_USER_IDS ?? '')
      .split(',')
      .map((value) => value.trim())
      .filter((value) => /^\d+$/.test(value))
      .filter((value) => value !== String(currentUserId));

    const unique = [...new Set(ids)];
    if (unique.length !== 5) {
      throw new BadRequestException(
        'GAME_ROOM_TEST_USER_IDS içinde mevcut kullanıcı hariç tam 5 test kullanıcı ID olmalı.',
      );
    }
    return unique;
  }

  async create(userId: string) {
    const testUserIds = this.testUserIds(userId);
    const memberIds = [String(userId), ...testUserIds];
    const client = await this.infra.db.connect();

    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(606061)');

      const profiles = await client.query<{ user_id: string }>(
        `select u.id::text as user_id
         from users u
         join profiles p on p.user_id=u.id
         where u.id = any($1::bigint[])
           and u.status='active'
           and p.profile_completed=true`,
        [memberIds],
      );
      const readyIds = new Set(profiles.rows.map((row) => row.user_id));
      const missing = memberIds.filter((id) => !readyIds.has(id));
      if (missing.length > 0) {
        throw new BadRequestException(
          `Mini oyun test kullanıcıları hazır değil: ${missing.join(', ')}`,
        );
      }

      const busy = await client.query<{ user_id: string; room_id: string }>(
        `select rm.user_id::text, rm.room_id::text
         from room_members rm
         join rooms r on r.id=rm.room_id
         where rm.user_id = any($1::bigint[])
           and rm.left_at is null
           and rm.admin_removed_at is null
           and r.status in ('active','selection')
         limit 1`,
        [memberIds],
      );
      if (busy.rows[0]) {
        throw new BadRequestException(
          `Test katılımcılarından biri aktif odada: ${busy.rows[0].user_id}`,
        );
      }

      const room = await client.query<{ id: string }>(
        `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
         values('active',now(),now()+interval '15 minutes',15,'game')
         returning id::text`,
      );
      const roomId = room.rows[0]?.id;
      if (!roomId) throw new BadRequestException('Mini oyun test odası oluşturulamadı.');

      for (const memberId of memberIds) {
        await client.query(
          'insert into room_members(room_id,user_id) values($1,$2)',
          [roomId, memberId],
        );
      }

      await client.query(
        'delete from matchmaking_queue where user_id = any($1::bigint[])',
        [memberIds],
      );
      await client.query(
        `insert into room_messages(room_id,sender_user_id,body)
         values($1,null,'Mini oyun test odası hazır: 5 test kullanıcı + sen.')`,
        [roomId],
      );

      await client.query('commit');
      return {
        ok: true,
        state: 'room',
        testMode: true,
        participantCount: 6,
        room: await this.rooms.getRoom(userId, roomId),
      };
    } catch (error) {
      await client.query('rollback');
      throw error;
    } finally {
      client.release();
    }
  }
}
