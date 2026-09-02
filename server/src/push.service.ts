import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
  type ServiceAccount,
} from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';

import { InfrastructureService } from './infrastructure.service';

interface PushNotificationRow {
  id: string;
  user_id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  push_attempts: number;
}

@Injectable()
export class PushService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PushService.name);
  private messaging: Messaging | null = null;
  private timer: NodeJS.Timeout | null = null;
  private working = false;

  constructor(private readonly infra: InfrastructureService) {
    this.initializeFirebase();
  }

  private initializeFirebase() {
    try {
      if (getApps().length === 0) {
        const inline = process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
        if (inline) {
          const serviceAccount = JSON.parse(inline) as ServiceAccount;
          initializeApp({ credential: cert(serviceAccount) });
        } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim()) {
          initializeApp({ credential: applicationDefault() });
        } else {
          this.logger.warn('Firebase credentials are not configured. Push worker is idle.');
          return;
        }
      }
      this.messaging = getMessaging();
      this.logger.log('Firebase Cloud Messaging push worker enabled.');
    } catch (error) {
      this.messaging = null;
      this.logger.error(`Firebase initialization failed: ${this.errorMessage(error)}`);
    }
  }

  onModuleInit() {
    this.timer = setInterval(() => void this.processOutbox(), 1250);
    this.timer.unref?.();
    void this.processOutbox();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  private errorMessage(error: unknown) {
    if (error instanceof Error) return error.message;
    return String(error ?? 'unknown push error');
  }

  async registerDevice(
    userId: string,
    tokenInput: string,
    platform: 'android' | 'ios' | 'web',
    appInstanceId?: string,
  ) {
    const token = tokenInput.trim();
    await this.infra.db.query(
      `insert into push_device_tokens(user_id, token, platform, app_instance_id)
       values($1,$2,$3,$4)
       on conflict(token) do update set
         user_id=excluded.user_id,
         platform=excluded.platform,
         app_instance_id=excluded.app_instance_id,
         enabled=true,
         last_seen_at=now(),
         updated_at=now()`,
      [userId, token, platform, appInstanceId?.trim() || null],
    );
    return { ok: true, firebaseConfigured: this.messaging != null };
  }

  async unregisterDevice(userId: string, tokenInput: string) {
    const token = tokenInput.trim();
    await this.infra.db.query(
      'delete from push_device_tokens where user_id=$1 and token=$2',
      [userId, token],
    );
    return { ok: true };
  }

  async status(userId: string) {
    const result = await this.infra.db.query<{ total: number }>(
      `select count(*)::int as total
       from push_device_tokens where user_id=$1 and enabled=true`,
      [userId],
    );
    return {
      ok: true,
      firebaseConfigured: this.messaging != null,
      registeredDevices: Number(result.rows[0]?.total ?? 0),
    };
  }

  async queueTest(userId: string) {
    const result = await this.infra.db.query<{ id: string }>(
      `insert into notifications(user_id,type,title,body,data)
       values($1,'push_test','Meet6 bildirim testi','Push bildirimleri çalışıyor.',jsonb_build_object('screen','home'))
       returning id::text`,
      [userId],
    );
    void this.processOutbox();
    return {
      ok: true,
      notificationId: result.rows[0]?.id,
      firebaseConfigured: this.messaging != null,
    };
  }

  private async claimBatch() {
    return this.infra.db.query<PushNotificationRow>(
      `with picked as (
         select id
         from notifications
         where push_processed_at is null
           and push_attempts < 5
           and (push_claimed_at is null or push_claimed_at < now() - interval '2 minutes')
         order by id asc
         limit 30
         for update skip locked
       )
       update notifications n
       set push_claimed_at=now(), push_attempts=n.push_attempts+1
       from picked
       where n.id=picked.id
       returning n.id::text, n.user_id::text, n.type, n.title, n.body, n.data, n.push_attempts`,
    );
  }

  private stringifyData(data: Record<string, unknown>, notification: PushNotificationRow) {
    const out: Record<string, string> = {
      type: notification.type,
      notificationId: notification.id,
    };
    for (const [key, value] of Object.entries(data ?? {})) {
      if (value == null) continue;
      out[key] = typeof value === 'string' ? value : JSON.stringify(value);
    }
    return out;
  }

  private async finish(
    id: string,
    { sent, error }: { sent: boolean; error?: string | null },
  ) {
    await this.infra.db.query(
      `update notifications
       set push_processed_at=now(),
           push_sent_at=case when $2 then now() else push_sent_at end,
           push_error=$3,
           push_claimed_at=null
       where id=$1`,
      [id, sent, error?.slice(0, 500) || null],
    );
  }

  private async retryLater(id: string, error: string) {
    await this.infra.db.query(
      `update notifications
       set push_claimed_at=null, push_error=$2
       where id=$1`,
      [id, error.slice(0, 500)],
    );
  }

  private isInvalidTokenCode(code?: string) {
    return code === 'messaging/registration-token-not-registered'
      || code === 'messaging/invalid-registration-token'
      || code === 'messaging/invalid-argument';
  }

  private async deliver(notification: PushNotificationRow) {
    if (!this.messaging) return;

    const settings = await this.infra.db.query<{
      notifications_enabled: boolean;
      room_reminders: boolean;
    }>(
      `select coalesce(us.notifications_enabled,true) as notifications_enabled,
              coalesce(us.room_reminders,true) as room_reminders
       from users u
       left join user_settings us on us.user_id=u.id
       where u.id=$1`,
      [notification.user_id],
    );
    const userSettings = settings.rows[0];
    if (!userSettings?.notifications_enabled) {
      await this.finish(notification.id, { sent: false, error: 'notifications_disabled' });
      return;
    }
    if (notification.type === 'room_found' && !userSettings.room_reminders) {
      await this.finish(notification.id, { sent: false, error: 'room_reminders_disabled' });
      return;
    }

    const devices = await this.infra.db.query<{ token: string }>(
      `select token from push_device_tokens
       where user_id=$1 and enabled=true
       order by updated_at desc
       limit 500`,
      [notification.user_id],
    );
    const tokens = devices.rows.map((row) => row.token);
    if (tokens.length === 0) {
      await this.finish(notification.id, { sent: false, error: 'no_device_tokens' });
      return;
    }

    const response = await this.messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: this.stringifyData(notification.data, notification),
      android: {
        priority: 'high',
        notification: {
          channelId: 'meet6_high',
          sound: 'default',
        },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: 'default' } },
      },
      webpush: {
        fcmOptions: { link: 'https://queensho.github.io/Meet6/' },
      },
    });

    const invalid: string[] = [];
    const transientErrors: string[] = [];
    response.responses.forEach((item, index) => {
      if (item.success) return;
      const code = item.error?.code;
      if (this.isInvalidTokenCode(code)) invalid.push(tokens[index]);
      else transientErrors.push(`${code ?? 'push_error'}:${item.error?.message ?? ''}`);
    });

    if (invalid.length) {
      await this.infra.db.query(
        'delete from push_device_tokens where token = any($1::text[])',
        [invalid],
      );
    }

    if (response.successCount > 0) {
      await this.finish(notification.id, {
        sent: true,
        error: response.failureCount > 0 ? `partial_failure:${response.failureCount}` : null,
      });
      return;
    }

    if (transientErrors.length === 0) {
      await this.finish(notification.id, { sent: false, error: 'all_tokens_invalid' });
      return;
    }

    if (notification.push_attempts >= 5) {
      await this.finish(notification.id, { sent: false, error: transientErrors.join(' | ') });
    } else {
      await this.retryLater(notification.id, transientErrors.join(' | '));
    }
  }

  async processOutbox() {
    if (!this.messaging || this.working) return;
    this.working = true;
    try {
      const batch = await this.claimBatch();
      for (const notification of batch.rows) {
        try {
          await this.deliver(notification);
        } catch (error) {
          const message = this.errorMessage(error);
          if (notification.push_attempts >= 5) {
            await this.finish(notification.id, { sent: false, error: message });
          } else {
            await this.retryLater(notification.id, message);
          }
          this.logger.warn(`Push ${notification.id} failed: ${message}`);
        }
      }
    } finally {
      this.working = false;
    }
  }
}
