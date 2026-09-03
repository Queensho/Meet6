import 'reflect-metadata';

import { randomUUID } from 'node:crypto';

import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';

import { AppModule } from './app.module';
import { InfrastructureService } from './infrastructure.service';
import { OpsExceptionFilter } from './ops-exception.filter';

type MiddlewareRequest = {
  method: string;
  path: string;
  ip?: string;
  opsRequestId?: string;
  socket: { remoteAddress?: string };
};

type MiddlewareResponse = {
  setHeader(name: string, value: string): void;
  status(code: number): MiddlewareResponse;
  json(body: unknown): void;
};

type MiddlewareNext = () => void;

function logProcessError(event: string, error: unknown) {
  const normalized = error instanceof Error
    ? { message: error.message, stack: error.stack ?? null }
    : { message: String(error), stack: null };

  // eslint-disable-next-line no-console
  console.error(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: 'error',
    event,
    service: 'meet6-api',
    ...normalized,
  }));
}

process.on('unhandledRejection', (reason) => {
  logProcessError('unhandled_rejection', reason);
  setImmediate(() => process.exit(1));
});

process.on('uncaughtException', (error) => {
  logProcessError('uncaught_exception', error);
  setImmediate(() => process.exit(1));
});

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    cors: false,
  });

  app.disable('x-powered-by');

  // nginx is the only public entry point in production. Trust exactly one proxy
  // hop so req.ip resolves to the real client IP from X-Forwarded-For.
  app.set('trust proxy', 1);

  app.use((
    req: MiddlewareRequest,
    res: MiddlewareResponse,
    next: MiddlewareNext,
  ) => {
    req.opsRequestId = randomUUID();
    res.setHeader('X-Request-Id', req.opsRequestId);
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Permitted-Cross-Domain-Policies', 'none');
    res.setHeader('Permissions-Policy', 'camera=(), microphone=(), payment=()');
    res.setHeader(
      'Content-Security-Policy',
      "default-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
    );
    res.setHeader('Strict-Transport-Security', 'max-age=31536000');
    next();
  });

  const origins = (process.env.CORS_ORIGINS ?? 'https://queensho.github.io')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

  if (process.env.NODE_ENV === 'production' && origins.includes('*')) {
    throw new Error('Wildcard CORS origin is forbidden in production');
  }

  app.enableCors({
    origin: origins,
    credentials: true,
    methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Accept'],
    maxAge: 600,
  });

  const infrastructure = app.get(InfrastructureService);
  const rateLimitEnabled = process.env.RATE_LIMIT_ENABLED !== 'false';

  if (process.env.NODE_ENV === 'production' && !rateLimitEnabled) {
    throw new Error('RATE_LIMIT_ENABLED=false is forbidden in production');
  }

  if (rateLimitEnabled) {
    app.use(async (
      req: MiddlewareRequest,
      res: MiddlewareResponse,
      next: MiddlewareNext,
    ) => {
      if (req.method === 'OPTIONS' || !req.path.startsWith('/api/')) {
        next();
        return;
      }

      if (req.path === '/api/health') {
        next();
        return;
      }

      const clientIp = req.ip || req.socket.remoteAddress || 'unknown';
      const isRequestCode = req.path === '/api/auth/request-code';
      const isVerifyCode = req.path === '/api/auth/verify-code';
      const isAuthSensitive = isRequestCode || isVerifyCode;

      const windowSeconds = isAuthSensitive ? 10 * 60 : 60;
      const limit = isRequestCode ? 5 : isVerifyCode ? 15 : 240;
      const bucket = isRequestCode
        ? 'auth-request-code'
        : isVerifyCode
          ? 'auth-verify-code'
          : 'api';
      const key = `meet6:rate:${bucket}:${clientIp}`;

      try {
        const count = await infrastructure.redis.incr(key);
        if (count === 1) {
          await infrastructure.redis.expire(key, windowSeconds);
        }

        const ttl = Math.max(0, await infrastructure.redis.ttl(key));
        const remaining = Math.max(0, limit - count);

        res.setHeader('RateLimit-Limit', String(limit));
        res.setHeader('RateLimit-Remaining', String(remaining));
        res.setHeader('RateLimit-Reset', String(ttl));

        if (count > limit) {
          res.setHeader('Retry-After', String(Math.max(1, ttl)));
          res.status(429).json({
            statusCode: 429,
            message: 'Too many requests. Please try again later.',
            error: 'Too Many Requests',
          });
          return;
        }
      } catch (error) {
        // Authentication endpoints fail closed so a Redis outage cannot disable
        // brute-force protection. Other authenticated API traffic remains
        // available while Redis recovers.
        // eslint-disable-next-line no-console
        console.warn('Rate limiter unavailable', error);

        if (isAuthSensitive) {
          res.setHeader('Retry-After', '30');
          res.status(503).json({
            statusCode: 503,
            message: 'Authentication is temporarily unavailable. Please try again shortly.',
            error: 'Service Unavailable',
          });
          return;
        }
      }

      next();
    });
  }

  const uploadRoot = process.env.UPLOAD_ROOT ?? '/var/www/meet6/uploads';
  app.useStaticAssets(uploadRoot, {
    prefix: '/uploads/',
    fallthrough: false,
    maxAge: '7d',
  });

  app.setGlobalPrefix('api');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new OpsExceptionFilter());

  const port = Number(process.env.PORT ?? 3100);
  await app.listen(port, '127.0.0.1');

  // eslint-disable-next-line no-console
  console.log(`Meet6 API listening on 127.0.0.1:${port}`);
}

void bootstrap().catch((error: unknown) => {
  logProcessError('bootstrap_failure', error);
  process.exit(1);
});
