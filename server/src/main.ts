import 'reflect-metadata';

import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';

import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    cors: false,
  });

  const origins = (process.env.CORS_ORIGINS ?? 'https://queensho.github.io')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean);

  app.enableCors({
    origin: origins,
    credentials: true,
  });

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
      transform: true,
    }),
  );

  const port = Number(process.env.PORT ?? 3100);
  await app.listen(port, '127.0.0.1');

  // eslint-disable-next-line no-console
  console.log(`Meet6 API listening on 127.0.0.1:${port}`);
}

void bootstrap();
