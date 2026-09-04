import {
  ForbiddenException,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { timingSafeEqual } from 'node:crypto';

import { InfrastructureService } from './infrastructure.service';

type SubscriptionRow = {
  user_id: string;
  provider: string;
  entitlement_id: string;
  product_id: string | null;
  store: string | null;
  environment: string | null;
  status: string;
  expires_at: Date | null;
  will_renew: boolean;
  original_transaction_id: string | null;
  last_event_id: string | null;
  last_event_at: Date | null;
  updated_at: Date;
};

type RevenueCatEntitlement = {
  expires_date?: string | null;
  product_identifier?: string | null;
  purchase_date?: string | null;
};

type RevenueCatSubscription = {
  expires_date?: string | null;
  unsubscribe_detected_at?: string | null;
  billing_issues_detected_at?: string | null;
  grace_period_expires_date?: string | null;
  original_purchase_date?: string | null;
  store?: string | null;
};

type RevenueCatSubscriberResponse = {
  subscriber?: {
    entitlements?: Record<string, RevenueCatEntitlement>;
    subscriptions?: Record<string, RevenueCatSubscription>;
  };
};

type RevenueCatWebhook = {
  event?: {
    id?: string;
    type?: string;
    app_user_id?: string;
    product_id?: string | null;
    store?: string | null;
    environment?: string | null;
    expiration_at_ms?: number | null;
    will_renew?: boolean | null;
    original_transaction_id?: string | null;
  };
};

@Injectable()
export class BillingService {
  constructor(private readonly infra: InfrastructureService) {}

  private get entitlementId() {
    return (process.env.REVENUECAT_PREMIUM_ENTITLEMENT ?? 'premium').trim() || 'premium';
  }

  private get secretApiKey() {
    return (process.env.REVENUECAT_SECRET_API_KEY ?? '').trim();
  }

  private isActiveRow(row: SubscriptionRow | undefined) {
    if (!row) return false;
    if (!['active', 'grace_period', 'billing_issue'].includes(row.status)) return false;
    return row.expires_at == null || new Date(row.expires_at).getTime() > Date.now();
  }

  private async row(userId: string) {
    const result = await this.infra.db.query<SubscriptionRow>(
      `select user_id::text, provider, entitlement_id, product_id, store, environment,
              status, expires_at, will_renew, original_transaction_id,
              last_event_id, last_event_at, updated_at
       from user_subscriptions
       where user_id=$1`,
      [userId],
    );
    return result.rows[0];
  }

  async isPremium(userId: string) {
    return this.isActiveRow(await this.row(userId));
  }

  async getSubscription(userId: string) {
    const row = await this.row(userId);
    const premium = this.isActiveRow(row);
    return {
      ok: true,
      premium,
      entitlementId: this.entitlementId,
      subscription: row
        ? {
            provider: row.provider,
            productId: row.product_id,
            store: row.store,
            environment: row.environment,
            status: row.status,
            expiresAt: row.expires_at,
            willRenew: row.will_renew,
            updatedAt: row.updated_at,
          }
        : null,
      benefits: {
        queuePriority: premium,
        roomDurationOptions: premium ? [15, 30] : [15],
        premiumRoomDurationMinutes: 30,
      },
    };
  }

  async assertRequestedRoomDuration(userId: string, requestedInput: unknown) {
    const requested = Number(requestedInput ?? 15);
    if (!Number.isInteger(requested) || ![15, 30].includes(requested)) {
      throw new ForbiddenException('Geçersiz oda süresi.');
    }

    const premium = await this.isPremium(userId);
    if (requested === 30 && !premium) {
      throw new ForbiddenException('30 dakikalık odalar Meet6 Premium özelliğidir.');
    }

    return {
      premium,
      priorityTier: premium ? 1 : 0,
      roomDurationMinutes: requested,
    };
  }

  private parseDate(value: string | null | undefined) {
    if (!value) return null;
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  private deriveRevenueCatState(payload: RevenueCatSubscriberResponse) {
    const subscriber = payload.subscriber ?? {};
    const entitlement = subscriber.entitlements?.[this.entitlementId];
    if (!entitlement) {
      return {
        status: 'inactive',
        productId: null,
        store: null,
        expiresAt: null,
        willRenew: false,
        originalTransactionId: null,
      };
    }

    const productId = entitlement.product_identifier?.toString() || null;
    const subscription = productId ? subscriber.subscriptions?.[productId] : undefined;
    const entitlementExpiry = this.parseDate(entitlement.expires_date);
    const graceExpiry = this.parseDate(subscription?.grace_period_expires_date);
    const effectiveExpiry = graceExpiry && graceExpiry.getTime() > (entitlementExpiry?.getTime() ?? 0)
      ? graceExpiry
      : entitlementExpiry;
    const active = effectiveExpiry == null || effectiveExpiry.getTime() > Date.now();

    let status = active ? 'active' : 'expired';
    if (active && subscription?.billing_issues_detected_at) status = 'billing_issue';
    if (graceExpiry && graceExpiry.getTime() > Date.now()) status = 'grace_period';

    return {
      status,
      productId,
      store: subscription?.store?.toString() || null,
      expiresAt: effectiveExpiry,
      willRenew: active && !subscription?.unsubscribe_detected_at,
      originalTransactionId: null,
    };
  }

  async syncFromRevenueCat(userId: string) {
    const key = this.secretApiKey;
    if (!key) {
      throw new ServiceUnavailableException(
        'RevenueCat sunucu doğrulaması yapılandırılmadı.',
      );
    }

    const response = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${key}`,
          Accept: 'application/json',
        },
      },
    );

    if (!response.ok) {
      throw new ServiceUnavailableException(
        `RevenueCat doğrulaması başarısız (${response.status}).`,
      );
    }

    const payload = await response.json() as RevenueCatSubscriberResponse;
    const state = this.deriveRevenueCatState(payload);
    await this.infra.db.query(
      `insert into user_subscriptions(
         user_id, provider, entitlement_id, product_id, store, status,
         expires_at, will_renew, original_transaction_id, provider_payload, updated_at
       ) values($1,'revenuecat',$2,$3,$4,$5,$6,$7,$8,$9::jsonb,now())
       on conflict(user_id) do update set
         provider='revenuecat', entitlement_id=excluded.entitlement_id,
         product_id=excluded.product_id, store=excluded.store,
         status=excluded.status, expires_at=excluded.expires_at,
         will_renew=excluded.will_renew,
         original_transaction_id=coalesce(excluded.original_transaction_id, user_subscriptions.original_transaction_id),
         provider_payload=excluded.provider_payload, updated_at=now()`,
      [
        userId,
        this.entitlementId,
        state.productId,
        state.store,
        state.status,
        state.expiresAt,
        state.willRenew,
        state.originalTransactionId,
        JSON.stringify(payload),
      ],
    );

    return this.getSubscription(userId);
  }

  private authorizeWebhook(authorization: string | undefined) {
    const expected = (process.env.REVENUECAT_WEBHOOK_AUTHORIZATION ?? '').trim();
    if (!expected) {
      if (process.env.NODE_ENV === 'production') {
        throw new ServiceUnavailableException('RevenueCat webhook doğrulaması yapılandırılmadı.');
      }
      throw new UnauthorizedException('RevenueCat webhook doğrulaması yapılandırılmadı.');
    }

    const actual = (authorization ?? '').trim();
    const left = Buffer.from(expected);
    const right = Buffer.from(actual);
    if (left.length !== right.length || !timingSafeEqual(left, right)) {
      throw new UnauthorizedException('Geçersiz RevenueCat webhook yetkilendirmesi.');
    }
  }

  private async applyWebhookFallback(userId: string, event: NonNullable<RevenueCatWebhook['event']>) {
    const expiresAt = event.expiration_at_ms == null
      ? null
      : new Date(Number(event.expiration_at_ms));
    const expired = event.type === 'EXPIRATION'
      || (expiresAt != null && expiresAt.getTime() <= Date.now());
    const status = expired
      ? 'expired'
      : event.type === 'BILLING_ISSUE'
        ? 'billing_issue'
        : 'active';

    await this.infra.db.query(
      `insert into user_subscriptions(
         user_id, provider, entitlement_id, product_id, store, environment,
         status, expires_at, will_renew, original_transaction_id,
         last_event_id, last_event_at, provider_payload, updated_at
       ) values($1,'revenuecat',$2,$3,$4,$5,$6,$7,$8,$9,$10,now(),$11::jsonb,now())
       on conflict(user_id) do update set
         product_id=coalesce(excluded.product_id,user_subscriptions.product_id),
         store=coalesce(excluded.store,user_subscriptions.store),
         environment=coalesce(excluded.environment,user_subscriptions.environment),
         status=excluded.status, expires_at=excluded.expires_at,
         will_renew=excluded.will_renew,
         original_transaction_id=coalesce(excluded.original_transaction_id,user_subscriptions.original_transaction_id),
         last_event_id=excluded.last_event_id, last_event_at=now(),
         provider_payload=excluded.provider_payload, updated_at=now()`,
      [
        userId,
        this.entitlementId,
        event.product_id ?? null,
        event.store ?? null,
        event.environment ?? null,
        status,
        expiresAt,
        event.will_renew === true,
        event.original_transaction_id ?? null,
        event.id ?? null,
        JSON.stringify({ event }),
      ],
    );
  }

  async handleRevenueCatWebhook(
    authorization: string | undefined,
    payload: RevenueCatWebhook,
  ) {
    this.authorizeWebhook(authorization);
    const event = payload?.event;
    const eventId = event?.id?.toString().trim() ?? '';
    const eventType = event?.type?.toString().trim() ?? '';
    const appUserId = event?.app_user_id?.toString().trim() ?? '';
    if (!eventId || !eventType) {
      throw new UnauthorizedException('RevenueCat webhook içeriği geçersiz.');
    }

    const userId = /^\d+$/.test(appUserId) ? appUserId : null;
    const inserted = await this.infra.db.query(
      `insert into subscription_events(provider,provider_event_id,user_id,event_type,payload)
       values('revenuecat',$1,$2,$3,$4::jsonb)
       on conflict(provider,provider_event_id) do nothing
       returning id`,
      [eventId, userId, eventType, JSON.stringify(payload)],
    );

    if (!userId) {
      return { ok: true, duplicate: inserted.rowCount === 0, ignored: true };
    }

    if (this.secretApiKey) {
      await this.syncFromRevenueCat(userId);
      await this.infra.db.query(
        `update user_subscriptions
         set last_event_id=$2,last_event_at=now(),environment=coalesce($3,environment),updated_at=now()
         where user_id=$1`,
        [userId, eventId, event.environment ?? null],
      );
    } else if (process.env.NODE_ENV !== 'production') {
      await this.applyWebhookFallback(userId, event);
    } else {
      throw new ServiceUnavailableException('RevenueCat sunucu doğrulaması yapılandırılmadı.');
    }

    return { ok: true, duplicate: inserted.rowCount === 0 };
  }
}
