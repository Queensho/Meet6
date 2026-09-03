import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';

import { RoomService } from './room.service';
import { RoomsGateway } from './rooms.gateway';

@Injectable()
export class MatchmakingSchedulerService implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;
  private running = false;

  constructor(
    private readonly rooms: RoomService,
    private readonly gateway: RoomsGateway,
  ) {}

  onModuleInit() {
    const configured = Number(process.env.MATCHMAKING_RETRY_SECONDS ?? 15);
    const seconds = Number.isFinite(configured)
      ? Math.max(5, Math.min(120, Math.floor(configured)))
      : 15;

    this.timer = setInterval(() => {
      void this.tick();
    }, seconds * 1000);
    this.timer.unref?.();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  private async tick() {
    if (this.running) return;
    this.running = true;
    try {
      const created = await this.rooms.processQueue();
      if (created) {
        await this.gateway.broadcastQueueStatus();
      }
    } catch (error) {
      // A transient database/socket failure must not stop future retries.
      // eslint-disable-next-line no-console
      console.warn('Matchmaking retry tick failed', error);
    } finally {
      this.running = false;
    }
  }
}
