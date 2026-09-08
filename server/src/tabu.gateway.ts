import { ConnectedSocket, MessageBody, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { AuthService } from './auth.service';
import { TabuGameService } from './tabu-game.service';

@WebSocketGateway({
  namespace: '/tabu',
  transports: ['websocket'],
  cors: {
    origin: ['https://www.meet6.com.tr','https://meet6.com.tr','https://queensho.github.io'],
    credentials: true,
  },
})
export class TabuGateway {
  @WebSocketServer() server!: Server;
  private readonly timers = new Map<string, NodeJS.Timeout>();
  private readonly forbiddenTimers = new Map<string, NodeJS.Timeout>();

  constructor(private readonly auth: AuthService, private readonly tabu: TabuGameService) {}

  private userId(client: Socket) {
    const id = client.data?.userId?.toString();
    if (!id) throw new Error('Socket oturumu doğrulanmadı.');
    return id;
  }

  private message(error: unknown) {
    if (error && typeof error === 'object') {
      const e = error as { message?: unknown; response?: { message?: unknown } };
      const m = e.response?.message ?? e.message;
      if (Array.isArray(m)) return m.join('\n');
      if (typeof m === 'string') return m;
    }
    return 'Tabu işlemi başarısız oldu.';
  }

  private async safe<T>(work: () => Promise<T>) {
    try { return { ok: true, ...((await work()) as object) }; }
    catch (error) { return { ok: false, error: this.message(error) }; }
  }

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token?.toString();
      const header = client.handshake.headers.authorization;
      const authorization = token ? `Bearer ${token}` : typeof header === 'string' ? header : undefined;
      const { userId } = await this.auth.userIdFromAuthorization(authorization);
      client.data.userId = userId;
      await client.join(`tabu-user:${userId}`);
      client.emit('tabu:ready', { ok: true, userId, timestamp: new Date().toISOString() });
    } catch (error) {
      client.emit('tabu:error', { message: this.message(error) });
      client.disconnect(true);
    }
  }

  private ensureTimer(roomId: string) {
    if (this.timers.has(roomId)) return;
    const timer = setInterval(async () => {
      const changed = await this.tabu.tick(roomId).catch(() => null);
      if (!changed) return;
      await this.broadcast(roomId, changed.event);
      if (changed.event === 'tabu:game_finished') {
        clearInterval(timer);
        this.timers.delete(roomId);
        const forbidden = this.forbiddenTimers.get(roomId);
        if (forbidden) clearTimeout(forbidden);
        this.forbiddenTimers.delete(roomId);
      }
    }, 500);
    this.timers.set(roomId, timer);
  }

  private scheduleForbiddenAdvance(roomId: string) {
    const runtime = this.tabu as any;
    const state = runtime.games?.get(roomId);
    if (!state || state.phase !== 'word_result' || state.lastResult?.kind !== 'tabu') return;

    const old = this.forbiddenTimers.get(roomId);
    if (old) clearTimeout(old);

    // UI tam 5 saniyeyi gösterebilsin; normal tick bu pencere içinde kelimeyi yeniden açmasın.
    const version = state.wordVersion;
    state.phaseEndsAtMs = Date.now() + 5_250;
    state.turnEndsAtMs = state.phaseEndsAtMs + 60_000;

    const timer = setTimeout(async () => {
      this.forbiddenTimers.delete(roomId);
      const current = runtime.games?.get(roomId);
      if (!current || current.phase !== 'word_result' || current.wordVersion !== version || current.lastResult?.kind !== 'tabu') return;

      // TABU turu anında bitirir. Aynı anlatıcının kalan 60 saniyesine geri dönülmez.
      current.turnStats.push({ ...current.currentTurn });
      await runtime.nextNarrator(current);
      await this.broadcast(roomId, current.phase === 'final' ? 'tabu:game_finished' : 'tabu:speaker_turn_ended');
    }, 5_000);

    this.forbiddenTimers.set(roomId, timer);
  }

  private async broadcast(roomId: string, event: string, eventData?: Record<string, unknown>) {
    const ids = this.tabu.memberIds(roomId);
    for (const userId of ids) {
      try {
        const state = await this.tabu.state(userId, roomId);
        const data: Record<string, unknown> = eventData ?? {};
        this.server.to(`tabu-user:${userId}`).emit(event, { roomId, state, ...data });
      } catch (_) {}
    }
  }

  @SubscribeMessage('tabu:join')
  join(@ConnectedSocket() client: Socket, @MessageBody() body: { roomId?: string }) {
    return this.safe(async () => {
      const roomId = body?.roomId?.toString() ?? '';
      const state = await this.tabu.state(this.userId(client), roomId);
      await client.join(`tabu-room:${roomId}`);
      this.ensureTimer(roomId);
      return { roomId, state };
    });
  }

  @SubscribeMessage('tabu:speaker_message')
  speakerMessage(@ConnectedSocket() client: Socket, @MessageBody() body: { roomId?: string; text?: string }) {
    return this.safe(async () => {
      const roomId = body?.roomId?.toString() ?? '';
      const result = await this.tabu.clue(this.userId(client), roomId, body?.text);
      if (result.event === 'tabu:forbidden_used') this.scheduleForbiddenAdvance(roomId);
      await this.broadcast(roomId, result.event, result.eventData as Record<string, unknown>);
      return { roomId, state: await this.tabu.state(this.userId(client), roomId) };
    });
  }

  @SubscribeMessage('tabu:guess_submitted')
  guess(@ConnectedSocket() client: Socket, @MessageBody() body: { roomId?: string; guess?: string }) {
    return this.safe(async () => {
      const roomId = body?.roomId?.toString() ?? '';
      const result = await this.tabu.guess(this.userId(client), roomId, body?.guess);
      await this.broadcast(roomId, result.event, result.eventData as Record<string, unknown>);
      return { roomId, state: await this.tabu.state(this.userId(client), roomId) };
    });
  }

  @SubscribeMessage('tabu:word_skipped')
  skip(@ConnectedSocket() client: Socket, @MessageBody() body: { roomId?: string }) {
    return this.safe(async () => {
      const roomId = body?.roomId?.toString() ?? '';
      const result = await this.tabu.pass(this.userId(client), roomId);
      await this.broadcast(roomId, result.event, result.eventData as Record<string, unknown>);
      return { roomId, state: await this.tabu.state(this.userId(client), roomId) };
    });
  }
}
