import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';
import { RoomService } from './room.service';

@Injectable()
export class RoomMessageService {
  constructor(
    private readonly infra: InfrastructureService,
    private readonly rooms: RoomService,
  ) {}

  private normalizeClientMessageId(value: string) {
    const id = value.trim();
    if (!/^[A-Za-z0-9._:-]{8,96}$/.test(id)) {
      throw new BadRequestException('Geçersiz mesaj kimliği.');
    }
    return id;
  }

  async sendMessage(
    userId: string,
    roomId: string | number,
    bodyInput: string,
    clientMessageIdInput: string,
  ) {
    const body = bodyInput.trim();
    if (!body) throw new BadRequestException('Mesaj boş olamaz.');
    if (body.length > 1000) throw new BadRequestException('Mesaj çok uzun.');

    const clientMessageId = this.normalizeClientMessageId(clientMessageIdInput);
    await this.rooms.syncExpiredRooms();

    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query('select pg_advisory_xact_lock(hashtext($1))', [
        `room-message:${roomId}:${userId}:${clientMessageId}`,
      ]);

      const existing = await client.query(
        `select id::text, sender_user_id::text, body, created_at
         from room_messages
         where room_id = $1
           and sender_user_id = $2
           and client_message_id = $3
         limit 1`,
        [roomId, userId, clientMessageId],
      );

      if (existing.rows[0]) {
        await client.query('commit');
        return { ok: true, message: existing.rows[0], deduplicated: true };
      }

      const membership = await client.query<{ status: string }>(
        `select r.status
         from rooms r
         join room_members rm on rm.room_id = r.id
         where r.id = $1
           and rm.user_id = $2
           and rm.admin_removed_at is null`,
        [roomId, userId],
      );

      if (!membership.rows[0]) {
        throw new ForbiddenException('Bu odaya erişimin yok.');
      }
      if (membership.rows[0].status !== 'active') {
        throw new BadRequestException('Oda sohbeti kapandı.');
      }

      const rateKey = `room-message:${roomId}:${userId}`;
      const allowed = await this.infra.redis.set(rateKey, '1', 'EX', 1, 'NX');
      if (!allowed) throw new BadRequestException('Çok hızlı mesaj gönderiyorsun.');

      const inserted = await client.query(
        `insert into room_messages(room_id, sender_user_id, body, client_message_id)
         values($1, $2, $3, $4)
         on conflict (room_id, sender_user_id, client_message_id)
           where client_message_id is not null
         do update set client_message_id = excluded.client_message_id
         returning id::text, sender_user_id::text, body, created_at`,
        [roomId, userId, body, clientMessageId],
      );

      const sender = await client.query<{ display_name: string | null }>(
        `select display_name from profiles where user_id=$1`,
        [userId],
      );
      const senderName = sender.rows[0]?.display_name?.trim() || 'Meet6';
      const pushBody = body.length > 480 ? `${body.slice(0, 477)}...` : body;
      const messageId = inserted.rows[0]?.id?.toString() ?? '';

      await client.query(
        `insert into notifications(user_id,type,title,body,data)
         select rm.user_id,
                'room_message',
                $3,
                $4,
                jsonb_build_object(
                  'roomId', $1::text,
                  'senderUserId', $2::text,
                  'messageId', $5::text
                )
         from room_members rm
         join users u on u.id=rm.user_id and u.status='active'
         where rm.room_id=$1
           and rm.user_id<>$2
           and rm.left_at is null
           and rm.admin_removed_at is null`,
        [roomId, userId, `${senderName} · Meet6 odası`, pushBody, messageId],
      );

      await client.query('commit');
      return { ok: true, message: inserted.rows[0], deduplicated: false };
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }
}
