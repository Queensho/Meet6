import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';

import { AuthService } from './auth.service';
import { InfrastructureService } from './infrastructure.service';
import { RoomMessageService } from './room-message.service';
import { RoomService } from './room.service';
import { SocialService } from './social.service';

@WebSocketGateway({
  namespace: '/rooms',
  transports: ['websocket'],
  cors: {
    origin: [
      'https://www.meet6.com.tr',
      'https://meet6.com.tr',
      'https://queensho.github.io',
    ],
    credentials: true,
  },
})
export class RoomsGateway {
  @WebSocketServer()
  server!: Server;

  private readonly roomTimers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly auth: AuthService,
    private readonly rooms: RoomService,
    private readonly roomMessageDelivery: RoomMessageService,
    private readonly social: SocialService,
    private readonly infra: InfrastructureService,
  ) {}

  private errorMessage(error: unknown) {
    if (error && typeof error === 'object') {
      const candidate = error as { message?: unknown; response?: { message?: unknown } };
      const responseMessage = candidate.response?.message;
      if (Array.isArray(responseMessage)) return responseMessage.join('\n');
      if (typeof responseMessage === 'string') return responseMessage;
      if (typeof candidate.message === 'string') return candidate.message;
    }
    return 'Gerçek zamanlı işlem başarısız oldu.';
  }

  private userId(client: Socket) {
    const userId = client.data?.userId?.toString();
    if (!userId) throw new Error('Socket oturumu doğrulanmadı.');
    return userId;
  }

  private async safe<T>(work: () => Promise<T>) {
    try {
      const value = await work();
      return { ok: true, ...((value ?? {}) as object) };
    } catch (error) {
      return { ok: false, error: this.errorMessage(error) };
    }
  }

  private numericAfter(value: unknown) {
    const parsed = Number(value ?? 0);
    if (!Number.isFinite(parsed) || parsed < 0) return 0;
    return Math.floor(parsed);
  }

  private async emitMatchesSnapshot(userId: string) {
    try {
      const snapshot = await this.social.listMatches(userId);
      this.server.to(`user:${userId}`).emit('matches:update', snapshot);
    } catch (_) {
      // Kullanıcı eşleşme listesine erişemiyorsa canlı akışı bozma.
    }
  }

  async handleConnection(client: Socket) {
    try {
      const authToken = client.handshake.auth?.token?.toString();
      const header = client.handshake.headers.authorization;
      const authorization = authToken
        ? `Bearer ${authToken}`
        : typeof header === 'string'
            ? header
            : undefined;
      const { userId } = await this.auth.userIdFromAuthorization(authorization);
      client.data.userId = userId;
      await client.join(`user:${userId}`);
      await this.infra.redis.sadd(`presence:${userId}`, client.id);
      await this.infra.redis.expire(`presence:${userId}`, 60 * 60 * 24);
      await this.infra.db.query('update users set last_seen_at=now() where id=$1', [userId]);
      await this.broadcastPresence(userId, true);
      client.emit('server:ready', {
        ok: true,
        userId,
        socketId: client.id,
        timestamp: new Date().toISOString(),
      });
      void this.emitMatchesSnapshot(userId);
    } catch (error) {
      client.emit('auth:error', { message: this.errorMessage(error) });
      client.disconnect(true);
    }
  }

  async handleDisconnect(client: Socket) {
    const userId = client.data?.userId?.toString();
    if (!userId) return;
    await this.infra.redis.srem(`presence:${userId}`, client.id).catch(() => undefined);
    const remaining = await this.infra.redis.scard(`presence:${userId}`).catch(() => 0);
    if (remaining === 0) {
      await this.infra.db.query('update users set last_seen_at=now() where id=$1', [userId]).catch(() => undefined);
      await this.broadcastPresence(userId, false);
    }
  }

  private async broadcastPresence(userId: string, online: boolean) {
    const setting = await this.infra.db.query<{ show_online: boolean }>(
      'select show_online from user_settings where user_id=$1',
      [userId],
    ).catch(() => ({ rows: [] as { show_online: boolean }[] }));
    const visible = setting.rows[0]?.show_online ?? true;
    this.server.emit('presence:update', {
      userId,
      online: visible ? online : false,
      timestamp: new Date().toISOString(),
    });
  }

  private async memberIds(roomId: string) {
    const result = await this.infra.db.query<{ user_id: string }>(
      'select user_id::text from room_members where room_id=$1 order by joined_at asc',
      [roomId],
    );
    return result.rows.map((row) => row.user_id);
  }

  async connectedUserIdsInRoom(roomId: string) {
    const connected = new Set<string>();
    try {
      const sockets = await (this.server as any).in(`room:${roomId}`).fetchSockets();
      for (const socket of sockets ?? []) {
        const userId = socket.data?.userId?.toString();
        if (userId) connected.add(userId);
      }
    } catch (_) {
      // Admin ekranı socket adapter hazır değilse boş bağlantı setiyle devam eder.
    }
    return connected;
  }

  async adminCloseRoom(roomId: string, reason: string) {
    const timer = this.roomTimers.get(roomId);
    if (timer) clearTimeout(timer);
    this.roomTimers.delete(roomId);
    this.server.to(`room:${roomId}`).emit('room:closed-by-admin', {
      roomId,
      reason,
      timestamp: new Date().toISOString(),
    });
    this.server.in(`room:${roomId}`).socketsLeave(`room:${roomId}`);
  }

  async adminRemoveMember(roomId: string, userId: string, reason: string) {
    this.server.to(`user:${userId}`).emit('room:removed', {
      roomId,
      reason,
      timestamp: new Date().toISOString(),
    });
    this.server.in(`user:${userId}`).socketsLeave(`room:${roomId}`);
  }

  async broadcastQueueStatus() {
    const queued = await this.infra.db.query<{ user_id: string }>(
      'select user_id::text from matchmaking_queue order by joined_at asc',
    );
    for (const row of queued.rows) {
      try {
        const status = await this.rooms.queueStatus(row.user_id);
        this.server.to(`user:${row.user_id}`).emit('queue:status', status);
      } catch (_) {
        // Bir kullanıcı aynı anda odaya alındıysa sıradaki yayına devam et.
      }
    }
  }

  private scheduleRoomDeadline(room: Record<string, any>) {
    const roomId = room.id?.toString();
    if (!roomId) return;
    const existing = this.roomTimers.get(roomId);
    if (existing) clearTimeout(existing);
    this.roomTimers.delete(roomId);

    const status = room.status?.toString();
    if (status !== 'active' && status !== 'selection') return;
    const seconds = status === 'active'
      ? Number(room.secondsLeft ?? 0)
      : Number(room.selectionSecondsLeft ?? 0);
    if (!Number.isFinite(seconds)) return;

    const timer = setTimeout(() => {
      void this.broadcastRoomUpdate(roomId);
    }, Math.max(250, seconds * 1000 + 180));
    this.roomTimers.set(roomId, timer);
  }

  async broadcastRoomUpdate(roomId: string) {
    try {
      await this.rooms.syncExpiredRooms();
      const ids = await this.memberIds(roomId);
      let firstRoom: Record<string, any> | null = null;
      for (const memberId of ids) {
        try {
          const room = await this.rooms.getRoom(memberId, roomId) as Record<string, any>;
          firstRoom ??= room;
          this.server.to(`user:${memberId}`).emit('room:update', { roomId, room });
        } catch (_) {
          // Admin tarafından odadan çıkarılan kullanıcı canlı snapshot alamaz.
        }
      }
      if (firstRoom) this.scheduleRoomDeadline(firstRoom);
    } catch (_) {
      // Oda silindiyse veya erişilemez olduysa timerı bırak.
    }
  }

  private async notifyMatchedRoom(room: Record<string, any>) {
    const roomId = room.id?.toString();
    if (!roomId) return;
    const ids = await this.memberIds(roomId);
    for (const memberId of ids) {
      this.server.in(`user:${memberId}`).socketsJoin(`room:${roomId}`);
      const personalized = await this.rooms.getRoom(memberId, roomId) as Record<string, any>;
      this.server.to(`user:${memberId}`).emit('queue:matched', {
        state: 'room',
        room: personalized,
      });
    }
    const firstId = ids[0];
    if (firstId) {
      const snapshot = await this.rooms.getRoom(firstId, roomId) as Record<string, any>;
      this.scheduleRoomDeadline(snapshot);
    }
    await this.broadcastQueueStatus();
  }

  @SubscribeMessage('ping')
  ping(@ConnectedSocket() client: Socket, @MessageBody() payload: unknown) {
    return {
      ok: true,
      socketId: client.id,
      payload: payload ?? null,
      timestamp: new Date().toISOString(),
    };
  }

  @SubscribeMessage('matches:list')
  matchesList(@ConnectedSocket() client: Socket) {
    return this.safe(async () => this.social.listMatches(this.userId(client)));
  }

  @SubscribeMessage('queue:join')
  queueJoin(@ConnectedSocket() client: Socket) {
    return this.safe(async () => {
      const result = await this.rooms.joinQueue(this.userId(client)) as Record<string, any>;
      if (result.state === 'room' && result.room) {
        await this.notifyMatchedRoom(result.room as Record<string, any>);
      } else {
        await this.broadcastQueueStatus();
      }
      return result;
    });
  }

  @SubscribeMessage('queue:status')
  queueStatus(@ConnectedSocket() client: Socket) {
    return this.safe(async () => this.rooms.queueStatus(this.userId(client)));
  }

  @SubscribeMessage('queue:cancel')
  queueCancel(@ConnectedSocket() client: Socket) {
    return this.safe(async () => {
      const result = await this.rooms.cancelQueue(this.userId(client));
      await this.broadcastQueueStatus();
      return result;
    });
  }

  @SubscribeMessage('room:join')
  roomJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { roomId?: string },
  ) {
    return this.safe(async () => {
      const userId = this.userId(client);
      const roomId = payload?.roomId?.toString() ?? '';
      const roomName = `room:${roomId}`;
      const alreadyJoined = client.rooms.has(roomName);
      const room = await this.rooms.getRoom(userId, roomId) as Record<string, any>;
      await client.join(roomName);
      if (!alreadyJoined) {
        await this.infra.db.query(
          `update room_members
           set connection_count=connection_count + 1, last_connected_at=now()
           where room_id=$1 and user_id=$2 and admin_removed_at is null`,
          [roomId, userId],
        );
      }
      this.scheduleRoomDeadline(room);
      return { roomId, room };
    });
  }

  @SubscribeMessage('room:messages')
  roomMessages(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { roomId?: string; after?: number | string },
  ) {
    return this.safe(async () => {
      const roomId = payload?.roomId?.toString() ?? '';
      return this.rooms.messages(
        this.userId(client),
        roomId,
        this.numericAfter(payload?.after),
      );
    });
  }

  @SubscribeMessage('room:leave')
  async roomLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { roomId?: string },
  ) {
    const roomId = payload?.roomId?.toString() ?? '';
    await client.leave(`room:${roomId}`);
    return { ok: true };
  }

  @SubscribeMessage('room:send')
  roomSend(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { roomId?: string; body?: string; clientMessageId?: string },
  ) {
    return this.safe(async () => {
      const userId = this.userId(client);
      const roomId = payload?.roomId?.toString() ?? '';
      const clientMessageId = payload?.clientMessageId?.toString().trim() ?? '';
      const result = clientMessageId
        ? await this.roomMessageDelivery.sendMessage(
            userId,
            roomId,
            payload?.body ?? '',
            clientMessageId,
          ) as Record<string, any>
        : await this.rooms.sendMessage(
            userId,
            roomId,
            payload?.body ?? '',
          ) as Record<string, any>;
      const profile = await this.infra.db.query<{ display_name: string; photo_urls: string[] }>(
        'select display_name, photo_urls from profiles where user_id=$1',
        [userId],
      );
      const message = {
        ...(result.message as object),
        display_name: profile.rows[0]?.display_name ?? 'Meet6',
        photo_urls: profile.rows[0]?.photo_urls ?? [],
      };
      this.server.to(`room:${roomId}`).emit('room:message', { roomId, message });
      return { message, deduplicated: result.deduplicated === true };
    });
  }

  @SubscribeMessage('room:extension')
  roomExtension(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { roomId?: string; vote?: boolean },
  ) {
    return this.safe(async () => {
      const roomId = payload?.roomId?.toString() ?? '';
      const result = await this.rooms.voteExtension(this.userId(client), roomId, payload?.vote === true);
      await this.broadcastRoomUpdate(roomId);
      this.server.to(`room:${roomId}`).emit('room:sync-messages', { roomId });
      return result;
    });
  }

  @SubscribeMessage('room:selection')
  roomSelection(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { roomId?: string; selectedUserId?: string | number },
  ) {
    return this.safe(async () => {
      const userId = this.userId(client);
      const roomId = payload?.roomId?.toString() ?? '';
      const selectedUserId = Number(payload?.selectedUserId);
      const result = await this.rooms.submitSelection(userId, roomId, selectedUserId) as Record<string, any>;
      client.emit('room:selection-status', { roomId, ...result });
      if (result.matched === true && result.matchId) {
        const event = { roomId, matchId: result.matchId.toString() };
        this.server.to(`user:${userId}`).emit('match:created', event);
        this.server.to(`user:${selectedUserId}`).emit('match:created', event);
        void this.emitMatchesSnapshot(userId);
        void this.emitMatchesSnapshot(String(selectedUserId));
      }
      return result;
    });
  }

  @SubscribeMessage('match:join')
  matchJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { matchId?: string },
  ) {
    return this.safe(async () => {
      const matchId = payload?.matchId?.toString() ?? '';
      const detail = await this.social.matchDetail(this.userId(client), matchId) as Record<string, any>;
      await client.join(`match:${matchId}`);
      return detail;
    });
  }

  @SubscribeMessage('match:messages')
  matchMessages(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { matchId?: string; after?: number | string },
  ) {
    return this.safe(async () => {
      const matchId = payload?.matchId?.toString() ?? '';
      return this.social.privateMessages(
        this.userId(client),
        matchId,
        this.numericAfter(payload?.after),
      );
    });
  }

  @SubscribeMessage('match:leave')
  async matchLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { matchId?: string },
  ) {
    const matchId = payload?.matchId?.toString() ?? '';
    await client.leave(`match:${matchId}`);
    return { ok: true };
  }

  @SubscribeMessage('match:send')
  matchSend(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { matchId?: string; body?: string },
  ) {
    return this.safe(async () => {
      const userId = this.userId(client);
      const matchId = payload?.matchId?.toString() ?? '';
      const result = await this.social.sendPrivateMessage(userId, matchId, payload?.body ?? '') as Record<string, any>;
      const pair = await this.infra.db.query<{ user_a_id: string; user_b_id: string }>(
        'select user_a_id::text, user_b_id::text from matches where id=$1',
        [matchId],
      );
      const row = pair.rows[0];
      const otherId = row?.user_a_id === userId ? row?.user_b_id : row?.user_a_id;
      const event = { matchId, message: result.message };
      this.server.to(`match:${matchId}`).emit('match:message', event);
      if (otherId) this.server.to(`user:${otherId}`).emit('user:message', event);
      void this.emitMatchesSnapshot(userId);
      if (otherId) void this.emitMatchesSnapshot(otherId);
      return result;
    });
  }

  @SubscribeMessage('match:read')
  matchRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { matchId?: string },
  ) {
    return this.safe(async () => {
      const userId = this.userId(client);
      const matchId = payload?.matchId?.toString() ?? '';
      const result = await this.social.markRead(userId, matchId);
      this.server.to(`match:${matchId}`).emit('match:read', {
        matchId,
        readerUserId: userId,
        readAt: new Date().toISOString(),
      });
      const pair = await this.infra.db.query<{ user_a_id: string; user_b_id: string }>(
        'select user_a_id::text, user_b_id::text from matches where id=$1',
        [matchId],
      );
      const row = pair.rows[0];
      void this.emitMatchesSnapshot(userId);
      if (row) {
        const otherId = row.user_a_id === userId ? row.user_b_id : row.user_a_id;
        void this.emitMatchesSnapshot(otherId);
      }
      return result;
    });
  }

  @SubscribeMessage('match:typing')
  matchTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { matchId?: string; typing?: boolean },
  ) {
    const matchId = payload?.matchId?.toString() ?? '';
    if (!client.rooms.has(`match:${matchId}`)) {
      return { ok: false, error: 'Önce sohbete bağlanmalısın.' };
    }
    client.to(`match:${matchId}`).emit('match:typing', {
      matchId,
      userId: this.userId(client),
      typing: payload?.typing === true,
    });
    return { ok: true };
  }
}
