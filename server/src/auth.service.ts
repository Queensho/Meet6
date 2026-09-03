import {
  BadRequestException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { createHmac, randomBytes } from 'node:crypto';

import { InfrastructureService } from './infrastructure.service';
import { normalizeTurkishPhone } from './phone.util';

@Injectable()
export class AuthService {
  constructor(private readonly infra: InfrastructureService) {}

  private hashCode(phone: string, code: string) {
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new Error('JWT_SECRET is required');
    return createHmac('sha256', secret).update(`${phone}:${code}`).digest('hex');
  }

  private async ensureUserAllowed(userId: string) {
    const [user, ban] = await Promise.all([
      this.infra.db.query<{ status: string }>('select status from users where id=$1', [userId]),
      this.infra.db.query<{ ends_at: Date | null; reason: string }>(
        `select ends_at, reason
         from user_bans
         where user_id=$1 and revoked_at is null and (ends_at is null or ends_at > now())
         order by created_at desc limit 1`,
        [userId],
      ).catch(() => ({ rows: [] as { ends_at: Date | null; reason: string }[] })),
    ]);

    const status = user.rows[0]?.status;
    if (!status) return;
    const activeBan = ban.rows[0];
    if (activeBan) {
      const suffix = activeBan.ends_at
        ? ` Ban bitişi: ${new Date(activeBan.ends_at).toISOString()}`
        : ' Bu ban kalıcıdır.';
      throw new ForbiddenException(`Hesabın Meet6 tarafından banlandı.${suffix}`);
    }

    if (status === 'banned') {
      await this.infra.db.query(`update users set status='active', updated_at=now() where id=$1`, [userId]);
      return;
    }
    if (status !== 'active') {
      throw new ForbiddenException('Bu hesap şu anda kullanıma açık değil.');
    }
  }

  private async ensurePhoneAllowed(phone: string) {
    const user = await this.infra.db.query<{ id: string }>(
      `select id::text from users where phone_e164=$1`,
      [phone],
    );
    const userId = user.rows[0]?.id;
    if (userId) await this.ensureUserAllowed(userId);
  }

  async requestCode(phoneInput: string) {
    const phone = normalizeTurkishPhone(phoneInput);
    const testMode = process.env.OTP_TEST_MODE === 'true';
    const testCode = process.env.OTP_TEST_CODE?.trim();

    if (!testMode || !testCode?.match(/^\d{6}$/)) {
      throw new ServiceUnavailableException('SMS sağlayıcısı henüz yapılandırılmadı.');
    }

    await this.ensurePhoneAllowed(phone);

    const rateKey = `otp:cooldown:${phone}`;
    const allowed = await this.infra.redis.set(rateKey, '1', 'EX', 60, 'NX');
    if (!allowed) {
      throw new HttpException('Yeni kod istemeden önce biraz bekle.', HttpStatus.TOO_MANY_REQUESTS);
    }

    await this.infra.db.query(
      `insert into otp_challenges(phone_e164, code_hash, expires_at)
       values ($1, $2, now() + interval '5 minutes')`,
      [phone, this.hashCode(phone, testCode)],
    );

    return { ok: true, phone, expiresInSeconds: 300, delivery: 'test' };
  }

  async verifyCode(phoneInput: string, code: string) {
    const phone = normalizeTurkishPhone(phoneInput);
    if (!/^\d{6}$/.test(code)) throw new BadRequestException('Kod 6 haneli olmalı.');
    await this.ensurePhoneAllowed(phone);

    const result = await this.infra.db.query<{
      id: string;
      code_hash: string;
      attempts: number;
      expires_at: Date;
    }>(
      `select id, code_hash, attempts, expires_at
       from otp_challenges
       where phone_e164 = $1 and consumed_at is null
       order by created_at desc
       limit 1`,
      [phone],
    );

    const challenge = result.rows[0];
    if (!challenge) throw new UnauthorizedException('Aktif doğrulama kodu yok.');
    if (challenge.attempts >= 5) throw new UnauthorizedException('Çok fazla hatalı deneme.');
    if (new Date(challenge.expires_at).getTime() < Date.now()) {
      throw new UnauthorizedException('Doğrulama kodunun süresi doldu.');
    }

    if (this.hashCode(phone, code) !== challenge.code_hash) {
      await this.infra.db.query(
        'update otp_challenges set attempts = attempts + 1 where id = $1',
        [challenge.id],
      );
      throw new UnauthorizedException('Doğrulama kodu yanlış.');
    }

    const client = await this.infra.db.connect();
    try {
      await client.query('begin');
      await client.query('update otp_challenges set consumed_at = now() where id = $1', [challenge.id]);
      const userResult = await client.query<{ id: string }>(
        `insert into users(phone_e164, last_seen_at)
         values ($1, now())
         on conflict (phone_e164)
         do update set last_seen_at = now(), updated_at = now()
         returning id`,
        [phone],
      );
      const userId = userResult.rows[0].id;
      await client.query(
        `insert into matching_preferences(user_id) values ($1)
         on conflict (user_id) do nothing`,
        [userId],
      );
      await client.query('commit');

      await this.ensureUserAllowed(userId);

      const sessionId = randomBytes(32).toString('base64url');
      const ttlSeconds = 60 * 60 * 24 * 30;
      const sessionsKey = `user-sessions:${userId}`;
      await this.infra.redis
        .multi()
        .set(`session:${sessionId}`, userId, 'EX', ttlSeconds)
        .sadd(sessionsKey, sessionId)
        .expire(sessionsKey, ttlSeconds)
        .exec();

      const profile = await this.infra.db.query<{ profile_completed: boolean }>(
        'select profile_completed from profiles where user_id = $1',
        [userId],
      );

      return {
        ok: true,
        sessionId,
        userId,
        profileCompleted: profile.rows[0]?.profile_completed ?? false,
      };
    } catch (error) {
      await client.query('rollback').catch(() => undefined);
      throw error;
    } finally {
      client.release();
    }
  }

  async userIdFromAuthorization(header?: string) {
    if (!header?.startsWith('Bearer ')) throw new UnauthorizedException('Oturum gerekli.');
    const sessionId = header.slice(7).trim();
    const userId = sessionId ? await this.infra.redis.get(`session:${sessionId}`) : null;
    if (!userId) throw new UnauthorizedException('Oturum geçersiz veya süresi dolmuş.');
    try {
      await this.ensureUserAllowed(userId);
    } catch (error) {
      await this.revokeAllSessions(userId).catch(() => undefined);
      throw error;
    }
    return { userId, sessionId };
  }

  async logout(header?: string) {
    const { userId, sessionId } = await this.userIdFromAuthorization(header);
    await this.infra.redis
      .multi()
      .del(`session:${sessionId}`)
      .srem(`user-sessions:${userId}`, sessionId)
      .exec();
    return { ok: true };
  }

  async revokeAllSessions(userId: string) {
    const key = `user-sessions:${userId}`;
    const sessionIds = await this.infra.redis.smembers(key);
    if (sessionIds.length) {
      await this.infra.redis.del(...sessionIds.map((id) => `session:${id}`));
    }
    await this.infra.redis.del(key);
  }
}
