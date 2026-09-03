import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';

import { InfrastructureService } from './infrastructure.service';
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
export class PrivateMessageGateway {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly social: SocialService,
    private readonly infra: InfrastructureService,
  ) {}

  private userId(client: Socket) {
    const userId = client.data?.userId?.toString();
    if (!userId) throw new Error('Socket oturumu doğrulanmadı.');
    return userId;
  }

  private errorMessage(error: unknown) {
    if (error && typeof error === 'object') {
      const candidate = error as { message?: unknown; response?: { message?: unknown } };
      const responseMessage = candidate.response?.message;
      if (Array.isArray(responseMessage)) return responseMessage.join('\n');
      if (typeof responseMessage === 'string') return responseMessage;
      if (typeof candidate.message === 'string') return candidate.message;
    }
    return 'Özel mesaj işlemi başarısız oldu.';
  }

  private async safe<T>(work: () => Promise<T>) {
    try {
      const value = await work();
      return { ok: true, ...((value ?? {}) as object) };
    } catch (error) {
      return { ok: false, error: this.errorMessage(error) };
    }
  }

  private async matchUsers(matchId: string) {
    const pair = await this.infra.db.query<{ user_a_id: string; user_b_id: string }>(
      'select user_a_id::text, user_b_id::text from matches where id=$1',
      [matchId],
    );
    const row = pair.rows[0];
    return row ? [row.user_a_id, row.user_b_id] : [];
  }

  private async emitMatchSnapshots(matchId: string) {
    const users = await this.matchUsers(matchId);
    for (const userId of users) {
      try {
        const snapshot = await this.social.listMatches(userId);
        this.server.to(`user:${userId}`).emit('matches:update', snapshot);
      } catch (_) {
        // Snapshot problemi canlı mesaj olayını bozmasın.
      }
    }
  }

  @SubscribeMessage('match:delivered')
  matchDelivered(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { matchId?: string; messageId?: string | number },
  ) {
    return this.safe(async () => {
      const userId = this.userId(client);
      const matchId = payload?.matchId?.toString() ?? '';
      const messageId = payload?.messageId?.toString() ?? '';
      const result = await this.social.markDelivered(userId, matchId, messageId);
      this.server.to(`match:${matchId}`).emit('match:delivered', {
        matchId,
        messageId: result.messageId,
        recipientUserId: userId,
        deliveredAt: result.deliveredAt,
      });
      return result;
    });
  }

  @SubscribeMessage('match:delete')
  matchDelete(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { matchId?: string; messageId?: string | number },
  ) {
    return this.safe(async () => {
      const userId = this.userId(client);
      const matchId = payload?.matchId?.toString() ?? '';
      const messageId = payload?.messageId?.toString() ?? '';
      const result = await this.social.deletePrivateMessage(userId, matchId, messageId);
      this.server.to(`match:${matchId}`).emit('match:message-deleted', {
        matchId,
        messageId: result.messageId,
        deletedByUserId: userId,
        deletedAt: new Date().toISOString(),
      });
      void this.emitMatchSnapshots(matchId);
      return result;
    });
  }
}
