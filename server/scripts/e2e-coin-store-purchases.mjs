import http from 'node:http';
import process from 'node:process';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';
import Redis from 'ioredis';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverDir = path.resolve(__dirname, '..');
const repoDir = path.resolve(serverDir, '..');

dotenv.config({ path: path.resolve(repoDir, '.env') });
dotenv.config({ path: path.resolve(serverDir, '.env'), override: false });

const API = process.env.E2E_API_BASE ?? 'http://127.0.0.1:3100/api';
const DATABASE_URL = process.env.DATABASE_URL;
const REDIS_URL = process.env.REDIS_URL;
const TEST_PHONE = '+905550060001';
const MOCK_PORT = 3199;

if (!DATABASE_URL) throw new Error('DATABASE_URL is required.');
if (!REDIS_URL) throw new Error('REDIS_URL is required.');

const pool = new pg.Pool({ connectionString: DATABASE_URL });
const redis = new Redis(REDIS_URL, { maxRetriesPerRequest: 2 });

async function activeSession(userId) {
  const ids = await redis.smembers(`user-sessions:${userId}`);
  for (const id of ids) {
    const owner = await redis.get(`session:${id}`);
    if (String(owner) === String(userId)) return id;
  }
  const sessionId = `coin-e2e-${randomUUID()}`;
  await redis.multi()
    .set(`session:${sessionId}`, String(userId), 'EX', 3600)
    .sadd(`user-sessions:${userId}`, sessionId)
    .expire(`user-sessions:${userId}`, 3600)
    .exec();
  return sessionId;
}

async function request(method, pathName, sessionId) {
  const response = await fetch(`${API}${pathName}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${sessionId}`,
    },
  });
  const text = await response.text();
  let data = {};
  if (text) {
    try { data = JSON.parse(text); } catch { data = { raw: text }; }
  }
  if (!response.ok) {
    throw new Error(`${method} ${pathName} -> ${response.status}: ${data.message ?? data.raw ?? 'error'}`);
  }
  return data;
}

function startRevenueCatMock(userId) {
  const server = http.createServer((req, res) => {
    const expectedPath = `/v1/subscribers/${encodeURIComponent(userId)}`;
    if (req.url !== expectedPath || req.method !== 'GET') {
      res.writeHead(404, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: 'not found' }));
      return;
    }
    if (req.headers.authorization !== 'Bearer coin-e2e-secret') {
      res.writeHead(401, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: 'unauthorized' }));
      return;
    }
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({
      subscriber: {
        non_subscriptions: {
          meet6_coins_100: [
            {
              id: 'coin-e2e-100-a',
              is_sandbox: true,
              purchase_date: '2026-09-05T10:00:00Z',
              store: 'play_store',
            },
          ],
          meet6_coins_300: [
            {
              id: 'coin-e2e-300-a',
              is_sandbox: true,
              purchase_date: '2026-09-05T10:01:00Z',
              store: 'play_store',
            },
          ],
          unknown_product: [
            {
              id: 'coin-e2e-unknown-a',
              is_sandbox: true,
              purchase_date: '2026-09-05T10:02:00Z',
              store: 'play_store',
            },
          ],
        },
      },
    }));
  });
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(MOCK_PORT, '127.0.0.1', () => resolve(server));
  });
}

async function main() {
  const found = await pool.query(
    'select id::text from users where phone_e164=$1 limit 1',
    [TEST_PHONE],
  );
  const userId = found.rows[0]?.id;
  if (!userId) throw new Error('Coin E2E user was not created by product E2E.');
  const sessionId = await activeSession(userId);

  await pool.query('insert into user_wallets(user_id) values($1) on conflict(user_id) do nothing', [userId]);
  const before = await pool.query('select coin_balance from user_wallets where user_id=$1', [userId]);
  const previousBalance = Number(before.rows[0]?.coin_balance ?? 0);

  await pool.query(
    `delete from wallet_transactions
     where user_id=$1 and idempotency_key like 'revenuecat:coin-e2e-%'`,
    [userId],
  );
  await pool.query(
    `delete from coin_purchase_receipts
     where user_id=$1 and provider_transaction_id like 'coin-e2e-%'`,
    [userId],
  );
  await pool.query('update user_wallets set coin_balance=0,updated_at=now() where user_id=$1', [userId]);

  const mock = await startRevenueCatMock(userId);
  try {
    const packs = await request('GET', '/coins/packs', sessionId);
    if (!Array.isArray(packs.products) || packs.products.length !== 4) {
      throw new Error(`Expected 4 configured coin products, got ${packs.products?.length}.`);
    }
    if (Number(packs.coinBalance) !== 0) {
      throw new Error(`Expected zero test balance before sync, got ${packs.coinBalance}.`);
    }

    const first = await request('POST', '/coins/sync', sessionId);
    if (Number(first.creditedPurchases) !== 2 || Number(first.creditedCoins) !== 400) {
      throw new Error(`First RevenueCat sync mismatch: ${JSON.stringify(first)}`);
    }
    if (Number(first.coinBalance) !== 400) {
      throw new Error(`Expected 400 coins after first sync, got ${first.coinBalance}.`);
    }

    const replay = await request('POST', '/coins/sync', sessionId);
    if (Number(replay.creditedPurchases) !== 0 || Number(replay.creditedCoins) !== 0) {
      throw new Error(`RevenueCat replay was credited twice: ${JSON.stringify(replay)}`);
    }
    if (Number(replay.coinBalance) !== 400) {
      throw new Error(`Balance changed on replay: ${replay.coinBalance}.`);
    }

    const receipts = await pool.query(
      `select count(*)::int as count
       from coin_purchase_receipts
       where user_id=$1 and provider_transaction_id like 'coin-e2e-%'`,
      [userId],
    );
    if (Number(receipts.rows[0]?.count) !== 2) {
      throw new Error('Expected exactly two credited RevenueCat receipts.');
    }

    const tx = await pool.query(
      `select count(*)::int as count,coalesce(sum(coin_delta),0)::int as coins
       from wallet_transactions
       where user_id=$1 and idempotency_key like 'revenuecat:coin-e2e-%'`,
      [userId],
    );
    if (Number(tx.rows[0]?.count) !== 2 || Number(tx.rows[0]?.coins) !== 400) {
      throw new Error(`Wallet transaction audit mismatch: ${JSON.stringify(tx.rows[0])}`);
    }

    console.log('✅ MEET6 COIN STORE PURCHASE E2E PASS');
    console.log('Rules: 4 packs → server-verified RevenueCat purchases → +400 coins → replay credits 0 → unknown product ignored');
  } finally {
    await new Promise((resolve) => mock.close(resolve));
    await pool.query(
      `delete from wallet_transactions
       where user_id=$1 and idempotency_key like 'revenuecat:coin-e2e-%'`,
      [userId],
    );
    await pool.query(
      `delete from coin_purchase_receipts
       where user_id=$1 and provider_transaction_id like 'coin-e2e-%'`,
      [userId],
    );
    await pool.query(
      'update user_wallets set coin_balance=$2,updated_at=now() where user_id=$1',
      [userId, previousBalance],
    );
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end().catch(() => undefined);
    redis.disconnect();
  });
