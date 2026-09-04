import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { createHash, createSign, randomUUID } from 'node:crypto';
import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import * as path from 'node:path';

import { InfrastructureService } from './infrastructure.service';

type UploadedPhoto = {
  buffer: Buffer;
  mimetype: string;
  size: number;
  originalname: string;
};

type ModerationDecision = 'approved' | 'review' | 'rejected';

type PhotoInspection = {
  decision: ModerationDecision;
  provider: string;
  reason: string | null;
  result: Record<string, unknown>;
  duplicateUsers: number;
  eventType?: string;
  eventScore?: number;
};

type GoogleServiceAccount = {
  client_email: string;
  private_key: string;
  token_uri?: string;
};

@Injectable()
export class ContentSafetyService {
  private googleToken: { value: string; expiresAt: number } | null = null;
  private serviceAccount: GoogleServiceAccount | null | undefined;

  constructor(private readonly infra: InfrastructureService) {}

  private uploadRoot() {
    return process.env.UPLOAD_ROOT ?? '/var/www/meet6/uploads';
  }

  private quarantineRoot() {
    return process.env.MODERATION_QUARANTINE_ROOT ?? '/var/lib/meet6/quarantine';
  }

  private riskLevel(score: number) {
    if (score >= 80) return 'critical';
    if (score >= 55) return 'high';
    if (score >= 25) return 'medium';
    return 'low';
  }

  private likelihood(value: unknown) {
    const rank: Record<string, number> = {
      UNKNOWN: 0,
      VERY_UNLIKELY: 1,
      UNLIKELY: 2,
      POSSIBLE: 3,
      LIKELY: 4,
      VERY_LIKELY: 5,
    };
    return rank[String(value ?? 'UNKNOWN').toUpperCase()] ?? 0;
  }

  private async loadGoogleServiceAccount() {
    if (this.serviceAccount !== undefined) return this.serviceAccount;

    const inline = process.env.GOOGLE_VISION_SERVICE_ACCOUNT_JSON?.trim();
    const credentialsPath = (
      process.env.GOOGLE_VISION_CREDENTIALS
      ?? process.env.GOOGLE_APPLICATION_CREDENTIALS
      ?? ''
    ).trim();

    try {
      const raw = inline || (credentialsPath ? await readFile(credentialsPath, 'utf8') : '');
      if (!raw) {
        this.serviceAccount = null;
        return null;
      }
      const parsed = JSON.parse(raw) as Partial<GoogleServiceAccount>;
      if (!parsed.client_email || !parsed.private_key) {
        this.serviceAccount = null;
        return null;
      }
      this.serviceAccount = {
        client_email: parsed.client_email,
        private_key: parsed.private_key.replace(/\\n/g, '\n'),
        token_uri: parsed.token_uri,
      };
      return this.serviceAccount;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn('Google Vision credentials could not be loaded', error);
      this.serviceAccount = null;
      return null;
    }
  }

  private async googleAccessToken() {
    if (this.googleToken && this.googleToken.expiresAt > Date.now() + 60_000) {
      return this.googleToken.value;
    }

    const credentials = await this.loadGoogleServiceAccount();
    if (!credentials) return null;

    const now = Math.floor(Date.now() / 1000);
    const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
    const claims = Buffer.from(JSON.stringify({
      iss: credentials.client_email,
      scope: 'https://www.googleapis.com/auth/cloud-platform',
      aud: credentials.token_uri ?? 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    })).toString('base64url');
    const unsigned = `${header}.${claims}`;
    const signature = createSign('RSA-SHA256')
      .update(unsigned)
      .end()
      .sign(credentials.private_key)
      .toString('base64url');
    const assertion = `${unsigned}.${signature}`;

    const response = await fetch(credentials.token_uri ?? 'https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    });
    if (!response.ok) {
      throw new Error(`Google OAuth failed with HTTP ${response.status}`);
    }
    const payload = await response.json() as { access_token?: string; expires_in?: number };
    if (!payload.access_token) throw new Error('Google OAuth response did not include access_token');
    this.googleToken = {
      value: payload.access_token,
      expiresAt: Date.now() + Math.max(300, Number(payload.expires_in ?? 3600)) * 1000,
    };
    return this.googleToken.value;
  }

  private async inspectWithGoogleVision(buffer: Buffer) {
    const token = await this.googleAccessToken();
    if (!token) return null;

    const projectId = process.env.GOOGLE_CLOUD_PROJECT_ID?.trim();
    const response = await fetch('https://vision.googleapis.com/v1/images:annotate', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json; charset=utf-8',
        ...(projectId ? { 'x-goog-user-project': projectId } : {}),
      },
      body: JSON.stringify({
        requests: [{
          image: { content: buffer.toString('base64') },
          features: [
            { type: 'SAFE_SEARCH_DETECTION' },
            { type: 'FACE_DETECTION', maxResults: 10 },
          ],
        }],
      }),
    });
    if (!response.ok) throw new Error(`Google Vision failed with HTTP ${response.status}`);

    const payload = await response.json() as {
      responses?: Array<{
        error?: { message?: string };
        safeSearchAnnotation?: Record<string, string>;
        faceAnnotations?: unknown[];
      }>;
    };
    const result = payload.responses?.[0];
    if (result?.error?.message) throw new Error(result.error.message);
    if (!result?.safeSearchAnnotation) throw new Error('Google Vision did not return SafeSearch data');
    return {
      safe: result.safeSearchAnnotation,
      faceCount: result.faceAnnotations?.length ?? 0,
    };
  }

  private async inspectPhoto(userId: string, file: UploadedPhoto): Promise<PhotoInspection> {
    const hash = createHash('sha256').update(file.buffer).digest('hex');
    const duplicateResult = await this.infra.db.query<{ count: string }>(
      `select count(distinct user_id)::text as count
       from photo_moderation_items
       where sha256=$1 and user_id<>$2 and status in ('approved','review')`,
      [hash, userId],
    ).catch(() => ({ rows: [{ count: '0' }] }));
    const duplicateUsers = Number(duplicateResult.rows[0]?.count ?? 0);

    let vision: Awaited<ReturnType<ContentSafetyService['inspectWithGoogleVision']>> = null;
    try {
      vision = await this.inspectWithGoogleVision(file.buffer);
    } catch (error) {
      // Moderation outages fail closed in production. The image is quarantined
      // for a moderator instead of being published without inspection.
      // eslint-disable-next-line no-console
      console.warn('Photo moderation provider unavailable', error);
      return {
        decision: process.env.NODE_ENV === 'production' ? 'review' : 'approved',
        provider: 'google-vision-unavailable',
        reason: process.env.NODE_ENV === 'production'
          ? 'Otomatik fotoğraf kontrolü tamamlanamadı; manuel inceleme gerekli.'
          : null,
        result: { providerUnavailable: true, sha256: hash },
        duplicateUsers,
      };
    }

    if (!vision) {
      return {
        decision: process.env.NODE_ENV === 'production' ? 'review' : 'approved',
        provider: 'not-configured',
        reason: process.env.NODE_ENV === 'production'
          ? 'Fotoğraf moderasyon servisi yapılandırılmadı; manuel inceleme gerekli.'
          : null,
        result: { moderationConfigured: false, sha256: hash },
        duplicateUsers,
      };
    }

    const safe = vision.safe;
    const adult = this.likelihood(safe.adult);
    const racy = this.likelihood(safe.racy);
    const violence = this.likelihood(safe.violence);
    const spoof = this.likelihood(safe.spoof);
    const result = { ...vision, sha256: hash, duplicateUsers };

    if (adult >= 4) {
      return {
        decision: 'rejected',
        provider: 'google-vision',
        reason: 'Fotoğraf yetişkin/çıplaklık içeriği nedeniyle reddedildi.',
        result,
        duplicateUsers,
        eventType: 'photo_explicit_content',
        eventScore: 45,
      };
    }
    if (violence >= 5) {
      return {
        decision: 'rejected',
        provider: 'google-vision',
        reason: 'Fotoğraf yüksek olasılıklı şiddet içeriği nedeniyle reddedildi.',
        result,
        duplicateUsers,
        eventType: 'photo_violent_content',
        eventScore: 40,
      };
    }
    if (duplicateUsers > 0) {
      return {
        decision: 'review',
        provider: 'google-vision',
        reason: 'Aynı fotoğraf başka bir hesapta kullanılmış; fake profil incelemesi gerekli.',
        result,
        duplicateUsers,
        eventType: 'photo_duplicate_account',
        eventScore: Math.min(45, 20 + duplicateUsers * 10),
      };
    }
    if (spoof >= 4) {
      return {
        decision: 'review',
        provider: 'google-vision',
        reason: 'Fotoğraf spoof/fake profil riski nedeniyle incelemeye alındı.',
        result,
        duplicateUsers,
        eventType: 'photo_spoof_signal',
        eventScore: 30,
      };
    }
    if (vision.faceCount < 1) {
      return {
        decision: 'review',
        provider: 'google-vision',
        reason: 'Profil fotoğrafında yüz tespit edilemedi; manuel inceleme gerekli.',
        result,
        duplicateUsers,
        eventType: 'photo_no_face',
        eventScore: 10,
      };
    }
    if (racy >= 5 || violence >= 4) {
      return {
        decision: 'review',
        provider: 'google-vision',
        reason: 'Fotoğraf hassas içerik sinyali nedeniyle manuel incelemeye alındı.',
        result,
        duplicateUsers,
      };
    }

    return {
      decision: 'approved',
      provider: 'google-vision',
      reason: null,
      result,
      duplicateUsers,
    };
  }

  async processProfilePhoto(userId: string, file: UploadedPhoto, extension: string) {
    const hash = createHash('sha256').update(file.buffer).digest('hex');
    const existing = await this.infra.db.query<{
      id: string;
      status: ModerationDecision;
      public_url: string | null;
      reason: string | null;
    }>(
      `select id::text, status, public_url, reason
       from photo_moderation_items
       where user_id=$1 and sha256=$2
       order by created_at desc limit 1`,
      [userId, hash],
    ).catch(() => ({ rows: [] as any[] }));
    const old = existing.rows[0];
    if (old?.status === 'approved' && old.public_url) {
      return {
        moderationId: old.id,
        status: old.status,
        url: old.public_url,
        reason: old.reason,
        duplicate: true,
      };
    }

    const inspection = await this.inspectPhoto(userId, file);
    const filename = `${Date.now()}-${randomUUID()}.${extension}`;
    let publicUrl: string | null = null;
    let quarantinePath: string | null = null;

    if (inspection.decision === 'approved') {
      const userDir = path.join(this.uploadRoot(), 'profile', userId);
      await mkdir(userDir, { recursive: true });
      await writeFile(path.join(userDir, filename), file.buffer, { flag: 'wx' });
      publicUrl = `/uploads/profile/${userId}/${filename}`;
    } else {
      const userDir = path.join(this.quarantineRoot(), 'profile', userId);
      await mkdir(userDir, { recursive: true });
      quarantinePath = path.join(userDir, filename);
      await writeFile(quarantinePath, file.buffer, { flag: 'wx' });
    }

    const inserted = await this.infra.db.query<{ id: string }>(
      `insert into photo_moderation_items(
         user_id, original_name, mime_type, sha256, status, provider,
         provider_result, reason, public_url, quarantine_path
       ) values($1,$2,$3,$4,$5,$6,$7::jsonb,$8,$9,$10)
       returning id::text`,
      [
        userId,
        file.originalname?.slice(0, 255) || null,
        file.mimetype,
        hash,
        inspection.decision,
        inspection.provider,
        JSON.stringify(inspection.result),
        inspection.reason,
        publicUrl,
        quarantinePath,
      ],
    );

    if (inspection.eventType && inspection.eventScore) {
      await this.recordSafetyEvent(
        userId,
        inspection.eventType,
        inspection.eventScore,
        { moderationId: inserted.rows[0].id, duplicateUsers: inspection.duplicateUsers },
      );
    } else {
      await this.recalculateRisk(userId).catch(() => undefined);
    }

    return {
      moderationId: inserted.rows[0].id,
      status: inspection.decision,
      url: publicUrl,
      reason: inspection.reason,
      duplicate: false,
    };
  }

  async listUserPhotos(userId: string) {
    const result = await this.infra.db.query(
      `select id::text, status, public_url, reason, provider, created_at, reviewed_at
       from photo_moderation_items
       where user_id=$1
       order by created_at desc
       limit 30`,
      [userId],
    );
    return { ok: true, photos: result.rows };
  }

  async recordSafetyEvent(
    userId: string | number,
    eventType: string,
    score: number,
    metadata: Record<string, unknown> = {},
  ) {
    await this.infra.db.query(
      `insert into safety_events(user_id,event_type,score,metadata)
       values($1,$2,$3,$4::jsonb)`,
      [userId, eventType.slice(0, 60), Math.max(0, Math.min(100, Math.round(score))), JSON.stringify(metadata)],
    );
    return this.recalculateRisk(String(userId));
  }

  async recalculateRisk(userId: string) {
    const [reports, safety, photos] = await Promise.all([
      this.infra.db.query<{
        reports_24h: string;
        reporters_24h: string;
        reports_7d: string;
      }>(
        `select
           count(*) filter (where created_at > now()-interval '24 hours')::text as reports_24h,
           count(distinct reporter_user_id) filter (where created_at > now()-interval '24 hours')::text as reporters_24h,
           count(*) filter (where created_at > now()-interval '7 days')::text as reports_7d
         from reports where reported_user_id=$1`,
        [userId],
      ),
      this.infra.db.query<{
        spam_score: string;
        fake_score: string;
        other_score: string;
      }>(
        `select
           coalesce(sum(score) filter (where event_type like 'message_%' or event_type like 'spam_%'),0)::text as spam_score,
           coalesce(sum(score) filter (where event_type like 'photo_duplicate%' or event_type like 'photo_spoof%' or event_type='photo_no_face'),0)::text as fake_score,
           coalesce(sum(score) filter (where event_type not like 'message_%' and event_type not like 'spam_%' and event_type not like 'photo_duplicate%' and event_type not like 'photo_spoof%' and event_type<>'photo_no_face'),0)::text as other_score
         from safety_events
         where user_id=$1 and created_at > now()-interval '7 days'`,
        [userId],
      ),
      this.infra.db.query<{ rejected: string; review: string }>(
        `select
           count(*) filter (where status='rejected' and created_at > now()-interval '30 days')::text as rejected,
           count(*) filter (where status='review' and created_at > now()-interval '30 days')::text as review
         from photo_moderation_items where user_id=$1`,
        [userId],
      ),
    ]);

    const reportRow = reports.rows[0];
    const safetyRow = safety.rows[0];
    const photoRow = photos.rows[0];
    const reporters24h = Number(reportRow?.reporters_24h ?? 0);
    const reports7d = Number(reportRow?.reports_7d ?? 0);
    const reportScore = Math.min(45, reporters24h * 12 + reports7d * 2);
    const spamScore = Math.min(35, Number(safetyRow?.spam_score ?? 0));
    const fakeScore = Math.min(35, Number(safetyRow?.fake_score ?? 0));
    const contentScore = Math.min(
      35,
      Number(safetyRow?.other_score ?? 0)
        + Number(photoRow?.rejected ?? 0) * 15
        + Number(photoRow?.review ?? 0) * 3,
    );
    const riskScore = Math.min(100, reportScore + spamScore + fakeScore + contentScore);
    const riskLevel = this.riskLevel(riskScore);

    const result = await this.infra.db.query(
      `insert into user_risk_profiles(
         user_id,risk_score,risk_level,report_score,spam_score,fake_score,last_evaluated_at,updated_at
       ) values($1,$2,$3,$4,$5,$6,now(),now())
       on conflict(user_id) do update set
         risk_score=excluded.risk_score,
         risk_level=excluded.risk_level,
         report_score=excluded.report_score,
         spam_score=excluded.spam_score,
         fake_score=excluded.fake_score,
         last_evaluated_at=now(),
         updated_at=now()
       returning *`,
      [userId, riskScore, riskLevel, reportScore, spamScore, fakeScore],
    );
    return result.rows[0];
  }

  private async applyTemporaryRestriction(userId: string, minutes: number, reason: string) {
    await this.infra.db.query(
      `insert into user_risk_profiles(user_id,restricted_until,restriction_reason,updated_at)
       values($1,now()+($2::text || ' minutes')::interval,$3,now())
       on conflict(user_id) do update set
         restricted_until=greatest(
           coalesce(user_risk_profiles.restricted_until,now()),
           now()+($2::text || ' minutes')::interval
         ),
         restriction_reason=$3,
         updated_at=now()`,
      [userId, Math.max(1, Math.round(minutes)), reason.slice(0, 500)],
    );
  }

  async assertMessageAllowed(userId: string, bodyInput: string) {
    const body = bodyInput.trim();
    if (!body) return;

    const restriction = await this.infra.db.query<{
      restricted_until: Date | null;
      restriction_reason: string | null;
    }>(
      `select restricted_until, restriction_reason
       from user_risk_profiles
       where user_id=$1 and restricted_until>now()`,
      [userId],
    ).catch(() => ({ rows: [] as any[] }));
    if (restriction.rows[0]?.restricted_until) {
      throw new ForbiddenException('Mesaj gönderme güvenlik incelemesi nedeniyle geçici olarak kısıtlandı.');
    }

    const minuteKey = `safety:message:minute:${userId}`;
    const minuteCount = await this.infra.redis.incr(minuteKey);
    if (minuteCount === 1) await this.infra.redis.expire(minuteKey, 60);
    if (minuteCount > 30) {
      await this.recordSafetyEvent(userId, 'message_burst_spam', 35, { minuteCount });
      await this.applyTemporaryRestriction(userId, 60, 'Aşırı mesaj gönderimi tespit edildi.');
      throw new BadRequestException('Çok fazla mesaj gönderdin. Bir süre sonra tekrar dene.');
    }

    const normalized = body.toLocaleLowerCase('tr-TR').replace(/\s+/g, ' ').slice(0, 1000);
    const bodyHash = createHash('sha256').update(normalized).digest('hex').slice(0, 24);
    const duplicateKey = `safety:message:duplicate:${userId}:${bodyHash}`;
    const duplicateCount = await this.infra.redis.incr(duplicateKey);
    if (duplicateCount === 1) await this.infra.redis.expire(duplicateKey, 10 * 60);
    if (duplicateCount > 5) {
      await this.recordSafetyEvent(userId, 'message_duplicate_spam', 45, { duplicateCount });
      await this.applyTemporaryRestriction(userId, 6 * 60, 'Aynı mesajın seri olarak gönderilmesi tespit edildi.');
      throw new BadRequestException('Aynı mesajı çok fazla kişiye gönderemezsin.');
    }

    const containsContactOrLink = /(https?:\/\/|t\.me\/|wa\.me\/|@[a-z0-9_]{4,}|(?:\+?90\s*)?5\d{9})/i.test(normalized.replace(/[\s()-]/g, ''));
    if (containsContactOrLink) {
      const contactKey = `safety:message:contact:${userId}`;
      const contactCount = await this.infra.redis.incr(contactKey);
      if (contactCount === 1) await this.infra.redis.expire(contactKey, 10 * 60);
      if (contactCount > 12) {
        await this.recordSafetyEvent(userId, 'message_contact_spam', 30, { contactCount });
        await this.applyTemporaryRestriction(userId, 2 * 60, 'Seri iletişim bilgisi/link paylaşımı tespit edildi.');
        throw new BadRequestException('Çok hızlı link veya iletişim bilgisi paylaşıyorsun.');
      }
    }
  }

  async triageReport(reportId: string, targetUserId: string | number, reasonInput: string) {
    const risk = await this.recalculateRisk(String(targetUserId));
    const recent = await this.infra.db.query<{
      reporters_24h: string;
      reports_24h: string;
    }>(
      `select
         count(distinct reporter_user_id)::text as reporters_24h,
         count(*)::text as reports_24h
       from reports
       where reported_user_id=$1 and created_at>now()-interval '24 hours'`,
      [targetUserId],
    );
    const reason = reasonInput.toLocaleLowerCase('tr-TR');
    const urgent = /(tehdit|şiddet|taciz|çıplak|cinsel|18 yaş|reşit değil|dolandır|sahte|fake|zorla|takip)/i.test(reason);
    const reporters24h = Number(recent.rows[0]?.reporters_24h ?? 0);
    const reports24h = Number(recent.rows[0]?.reports_24h ?? 0);
    const priorityScore = Math.min(
      100,
      Number(risk?.risk_score ?? 0)
        + Math.min(35, reporters24h * 10)
        + (urgent ? 25 : 0),
    );
    const flags = {
      urgentReason: urgent,
      distinctReporters24h: reporters24h,
      reports24h,
      riskLevel: risk?.risk_level ?? 'low',
      riskScore: Number(risk?.risk_score ?? 0),
    };
    await this.infra.db.query(
      `update reports
       set priority_score=$2, triage_flags=$3::jsonb, updated_at=now()
       where id=$1`,
      [reportId, priorityScore, JSON.stringify(flags)],
    );
    return { priorityScore, flags, risk };
  }

  async reviewPhoto(
    moderationId: string,
    adminUserId: string,
    action: 'approve' | 'reject',
    note?: string,
  ) {
    const result = await this.infra.db.query<{
      id: string;
      user_id: string;
      status: ModerationDecision;
      public_url: string | null;
      quarantine_path: string | null;
    }>(
      `select id::text,user_id::text,status,public_url,quarantine_path
       from photo_moderation_items where id=$1`,
      [moderationId],
    );
    const item = result.rows[0];
    if (!item) throw new BadRequestException('Fotoğraf moderasyon kaydı bulunamadı.');

    let publicUrl = item.public_url;
    if (action === 'approve' && !publicUrl) {
      if (!item.quarantine_path) throw new BadRequestException('İncelenecek karantina dosyası bulunamadı.');
      const extension = path.extname(item.quarantine_path) || '.jpg';
      const filename = `${Date.now()}-${randomUUID()}${extension}`;
      const userDir = path.join(this.uploadRoot(), 'profile', item.user_id);
      await mkdir(userDir, { recursive: true });
      const destination = path.join(userDir, filename);
      await copyFile(item.quarantine_path, destination);
      await rm(item.quarantine_path, { force: true });
      publicUrl = `/uploads/profile/${item.user_id}/${filename}`;

      await this.infra.db.query(
        `update profiles
         set photo_urls=case
           when $2 = any(coalesce(photo_urls,'{}'::text[])) then photo_urls
           when cardinality(coalesce(photo_urls,'{}'::text[])) < 4
             then array_append(coalesce(photo_urls,'{}'::text[]),$2)
           else photo_urls
         end,
         updated_at=now()
         where user_id=$1`,
        [item.user_id, publicUrl],
      );
    }

    if (action === 'reject') {
      if (item.quarantine_path) await rm(item.quarantine_path, { force: true }).catch(() => undefined);
      if (item.public_url?.startsWith('/uploads/profile/')) {
        const relative = item.public_url.replace(/^\/uploads\//, '');
        await rm(path.join(this.uploadRoot(), relative), { force: true }).catch(() => undefined);
        await this.infra.db.query(
          `update profiles
           set photo_urls=array_remove(coalesce(photo_urls,'{}'::text[]),$2), updated_at=now()
           where user_id=$1`,
          [item.user_id, item.public_url],
        );
      }
      publicUrl = null;
    }

    await this.infra.db.query(
      `update photo_moderation_items
       set status=$2,
           public_url=$3,
           quarantine_path=null,
           reviewed_by_admin_id=$4,
           reviewed_at=now(),
           reason=case when $5::text='' then reason else $5 end,
           updated_at=now()
       where id=$1`,
      [moderationId, action === 'approve' ? 'approved' : 'rejected', publicUrl, adminUserId, note?.trim() ?? ''],
    );

    if (action === 'reject') {
      await this.recordSafetyEvent(item.user_id, 'photo_manual_reject', 25, { moderationId });
    } else {
      await this.recalculateRisk(item.user_id).catch(() => undefined);
    }

    return {
      ok: true,
      moderationId,
      status: action === 'approve' ? 'approved' : 'rejected',
      publicUrl,
    };
  }
}
