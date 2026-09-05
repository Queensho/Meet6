import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import { InfrastructureService } from './infrastructure.service';

type CoinProductRow = {
  product_id: string;
  coin_amount: number;
  sort_order: number;
};

type RevenueCatNonSubscriptionPurchase = {
  id?: string | null;
  is_sandbox?: boolean | null;
  purchase_date?: string | null;
  store?: string | null;
};

type RevenueCatCustomerInfo = {
  subscriber?: {
    non_subscriptions?: Record<string, RevenueCatNonSubscriptionPurchase[]>;
  };
};

@Injectable()
export class CoinPurchaseService {
  constructor(private readonly infra: InfrastructureService) {}

  private get secretApiKey() {
    return (process.env.REVENUECAT_SECRET_API_KEY ?? '').trim();
  }

  private get revenueCatApiBaseUrl() {
    return (process.env.REVENUECAT_API_BASE_URL ?? 'https://api.revenuecat.com/v1')
      .trim()
      .replace(/\/+$/, '');
  }

  private async ensureWallet(userId: string) {
    await this.infra.db.query(
      `insert into user_wallets(user_id) values($1)
       on conflict(user_id) do nothing`,
      [userId],
    );
  }

  private async balance(userId: string) {
    await this.ensureWallet(userId);
    const result = await this.infra.db.query<{ coin_balance: number }>(
      'select coin_balance from user_wallets where user_id=$1',
      [userId],
    );
    return Number(result.rows[0]?.coin_balance ?? 0);
  }

  async packs(userId: string) {
    const [products, coinBalance] = await Promise.all([
      this.infra.db.query<CoinProductRow>(
        `select product_id,coin_amount,sort_order
         from coin_products
         where active=true
         order by sort_order asc,id asc`,
      ),
      this.balance(userId),
    ]);

    return {
      ok: true,
      coinBalance,
      provider: 'revenuecat',
      products: products.rows.map((row) => ({
        productId: row.product_id,
        coinAmount: Number(row.coin_amount),
      })),
    };
  }

  private async customerInfo(userId: string) {
    const apiKey = this.secretApiKey;
    if (!apiKey) {
      throw new ServiceUnavailableException('RevenueCat jeton doğrulaması yapılandırılmadı.');
    }

    const response = await fetch(
      `${this.revenueCatApiBaseUrl}/subscribers/${encodeURIComponent(userId)}`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          Accept: 'application/json',
        },
      },
    );

    if (!response.ok) {
      throw new ServiceUnavailableException(
        `RevenueCat jeton doğrulaması başarısız (${response.status}).`,
      );
    }
    return await response.json() as RevenueCatCustomerInfo;
  }

  async sync(userId: string) {
    const [payload, configured] = await Promise.all([
      this.customerInfo(userId),
      this.infra.db.query<CoinProductRow>(
        `select product_id,coin_amount,sort_order
         from coin_products where active=true`,
      ),
    ]);

    const productCoins = new Map(
      configured.rows.map((row) => [row.product_id, Number(row.coin_amount)]),
    );
    const purchases: Array<{
      productId: string;
      transactionId: string;
      purchaseDate: string | null;
      store: string | null;
      sandbox: boolean;
      coinAmount: number;
      payload: RevenueCatNonSubscriptionPurchase;
    }> = [];

    const nonSubscriptions = payload.subscriber?.non_subscriptions ?? {};
    for (const [productId, rows] of Object.entries(nonSubscriptions)) {
      const coinAmount = productCoins.get(productId);
      if (!coinAmount || !Array.isArray(rows)) continue;
      for (const purchase of rows) {
        const transactionId = purchase?.id?.toString().trim() ?? '';
        if (!transactionId) continue;
        purchases.push({
          productId,
          transactionId,
          purchaseDate: purchase.purchase_date?.toString() || null,
          store: purchase.store?.toString() || null,
          sandbox: purchase.is_sandbox === true,
          coinAmount,
          payload: purchase,
        });
      }
    }

    purchases.sort((a, b) => {
      const left = a.purchaseDate ? new Date(a.purchaseDate).getTime() : 0;
      const right = b.purchaseDate ? new Date(b.purchaseDate).getTime() : 0;
      return left - right;
    });

    let creditedCoins = 0;
    let creditedPurchases = 0;

    for (const purchase of purchases) {
      const client = await this.infra.db.connect();
      try {
        await client.query('begin');
        await client.query('insert into user_wallets(user_id) values($1) on conflict(user_id) do nothing', [userId]);

        const receipt = await client.query<{ id: string }>(
          `insert into coin_purchase_receipts(
             user_id,provider,product_id,provider_transaction_id,store,
             purchased_at,coin_amount,provider_payload
           ) values($1,'revenuecat',$2,$3,$4,$5,$6,$7::jsonb)
           on conflict(provider,provider_transaction_id) do nothing
           returning id::text`,
          [
            userId,
            purchase.productId,
            purchase.transactionId,
            purchase.store,
            purchase.purchaseDate,
            purchase.coinAmount,
            JSON.stringify(purchase.payload),
          ],
        );

        const receiptId = receipt.rows[0]?.id;
        if (!receiptId) {
          await client.query('commit');
          continue;
        }

        const wallet = await client.query<{ coin_balance: number }>(
          `update user_wallets
           set coin_balance=coin_balance+$2,updated_at=now()
           where user_id=$1
           returning coin_balance`,
          [userId, purchase.coinAmount],
        );
        const balanceAfter = Number(wallet.rows[0]?.coin_balance ?? 0);

        await client.query(
          `insert into wallet_transactions(
             user_id,transaction_type,coin_delta,balance_after,
             reference_type,reference_id,idempotency_key,metadata
           ) values(
             $1,'coin_purchase',$2,$3,'coin_purchase',$4,$5,$6::jsonb
           )`,
          [
            userId,
            purchase.coinAmount,
            balanceAfter,
            receiptId,
            `revenuecat:${purchase.transactionId}`,
            JSON.stringify({
              productId: purchase.productId,
              store: purchase.store,
              sandbox: purchase.sandbox,
            }),
          ],
        );

        await client.query('commit');
        creditedCoins += purchase.coinAmount;
        creditedPurchases += 1;
      } catch (error) {
        await client.query('rollback').catch(() => undefined);
        throw error;
      } finally {
        client.release();
      }
    }

    return {
      ok: true,
      creditedCoins,
      creditedPurchases,
      coinBalance: await this.balance(userId),
    };
  }
}
