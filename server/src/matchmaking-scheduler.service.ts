import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';

import { RoomRefillService } from './room-refill.service';
import { RoomService } from './room.service';
import { RoomsGateway } from './rooms.gateway';

@Injectable()
export class MatchmakingSchedulerService implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;
  private running = false;

  constructor(
    private readonly rooms: RoomService,
    private readonly refills: RoomRefillService,
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
      // During the first five minutes, fill empty seats in active text rooms
      // before creating brand-new six-person rooms.
      const refilledRooms = await this.refills.processOpenSeats();
      if (refilledRooms.length) {
        for (const roomId of refilledRooms) {
          await this.gateway.broadcastRoomUpdate(roomId);
        }
        // Refilled users deliberately remain in matchmaking_queue until this
        // snapshot runs, so queueStatus can deliver their matched room in realtime.
        await this.gateway.broadcastQueueStatus();
      }

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
