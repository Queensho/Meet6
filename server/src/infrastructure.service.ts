import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import Redis from 'ioredis';
import { Pool } from 'pg';

@Injectable()
export class InfrastructureService implements OnModuleInit, OnModuleDestroy {
  readonly db: Pool;
  readonly redis: Redis;

  constructor() {
    const databaseUrl = process.env.DATABASE_URL;
    const redisUrl = process.env.REDIS_URL;

    if (!databaseUrl) throw new Error('DATABASE_URL is required');
    if (!redisUrl) throw new Error('REDIS_URL is required');

    this.db = new Pool({
      connectionString: databaseUrl,
      max: 10,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
    });

    this.redis = new Redis(redisUrl, {
      lazyConnect: true,
      maxRetriesPerRequest: 2,
      enableReadyCheck: true,
    });
  }

  async onModuleInit() {
    await this.db.query('select 1');
    await this.redis.connect();
    await this.redis.ping();
  }

  async onModuleDestroy() {
    await Promise.allSettled([this.db.end(), this.redis.quit()]);
  }

  async health() {
    const started = Date.now();
    const dbResult = await this.db.query<{ now: Date }>('select now() as now');
    const redisResult = await this.redis.ping();

    return {
      database: 'ok',
      databaseTime: dbResult.rows[0]?.now ?? null,
      redis: redisResult === 'PONG' ? 'ok' : redisResult,
      latencyMs: Date.now() - started,
    };
  }
}
