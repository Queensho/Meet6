import process from 'node:process';
import path from 'node:path';
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
const TEST_PHONES = [
  '+905550060001', '+905550060002', '+905550060003',
  '+905550060004', '+905550060005', '+905550060006',
];

if (!DATABASE_URL) throw new Error('DATABASE_URL is required.');
if (!REDIS_URL) throw new Error('REDIS_URL is required.');

const pool = new pg.Pool({ connectionString: DATABASE_URL });
const redis = new Redis(REDIS_URL, { maxRetriesPerRequest: 2 });

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function activeSession(userId) {
  const ids = await redis.smembers(`user-sessions:${userId}`);
  for (const id of ids) {
    const owner = await redis.get(`session:${id}`);
    if (String(owner) === String(userId)) return id;
  }
  throw new Error(`No active session for CI user ${userId}.`);
}

async function request(method, urlPath, sessionId, body) {
  const response = await fetch(`${API}${urlPath}`, {
    method,
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${sessionId}`,
      ...(body == null ? {} : { 'Content-Type': 'application/json' }),
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = {};
  if (text) {
    try { data = JSON.parse(text); } catch { data = { raw: text }; }
  }
  return { response, data };
}

async function ok(method, urlPath, sessionId, body) {
  const { response, data } = await request(method, urlPath, sessionId, body);
  if (!response.ok) {
    throw new Error(`${method} ${urlPath} -> ${response.status}: ${data.message ?? data.raw ?? response.statusText}`);
  }
  return data;
}

async function cleanup(ids) {
  await pool.query(
    `update rooms r
     set status='closed', closed_at=coalesce(closed_at, now())
     where r.id in (select distinct room_id from room_members where user_id=any($1::bigint[]))`,
    [ids],
  );
  await pool.query(
    `update room_members set left_at=coalesce(left_at, now())
     where user_id=any($1::bigint[])`,
    [ids],
  );
  await pool.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [ids]);
}

async function waitForRoom(users, timeoutMs = 6000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const statuses = await Promise.all(
      users.map((user) => ok('GET', '/rooms/queue', user.sessionId)),
    );
    if (statuses.every((status) => status.state === 'room')) return statuses;
    await sleep(200);
  }
  throw new Error('Premium 30-minute room did not form.');
}

async function main() {
  const result = await pool.query(
    `select id::text, phone_e164 from users
     where phone_e164=any($1::text[]) order by phone_e164 asc`,
    [TEST_PHONES],
  );
  if (result.rows.length !== 6) throw new Error(`Expected 6 E2E users, found ${result.rows.length}.`);

  const users = [];
  for (const row of result.rows) users.push({ ...row, sessionId: await activeSession(row.id) });
  const ids = users.map((user) => user.id);

  await cleanup(ids);
  // The preceding matchmaking-policy E2E has already tested permanent exclusions.
  // Make this scenario independent from its final control room.
  await pool.query(
    `update rooms set started_at=now()-interval '2 days'
     where id in (select distinct room_id from room_members where user_id=any($1::bigint[]))`,
    [ids],
  );
  await pool.query(
    `delete from matches where user_a_id=any($1::bigint[]) and user_b_id=any($1::bigint[])`,
    [ids],
  );
  await pool.query(
    `delete from reports where reporter_user_id=any($1::bigint[]) and reported_user_id=any($1::bigint[])`,
    [ids],
  );
  await pool.query(
    `delete from blocked_users where blocker_user_id=any($1::bigint[]) and blocked_user_id=any($1::bigint[])`,
    [ids],
  );
  await pool.query('delete from user_subscriptions where user_id=any($1::bigint[])', [ids]);

  // Free users can never self-assert the 30-minute entitlement.
  const denied = await request(
    'POST',
    '/rooms/queue',
    users[0].sessionId,
    { roomDurationMinutes: 30 },
  );
  if (denied.response.status !== 403) {
    throw new Error(`Expected free 30-minute request to be 403, got ${denied.response.status}.`);
  }

  // Grant six CI users an active server-side entitlement and form a 30-minute pool.
  for (const user of users) {
    await pool.query(
      `insert into user_subscriptions(user_id,status,expires_at,will_renew,product_id,store)
       values($1,'active',now()+interval '30 days',true,'meet6_premium_ci','PLAY_STORE')
       on conflict(user_id) do update set
         status='active',expires_at=excluded.expires_at,will_renew=true,
         product_id=excluded.product_id,store=excluded.store,updated_at=now()`,
      [user.id],
    );
  }

  for (const user of users) {
    await ok('POST', '/rooms/queue', user.sessionId, { roomDurationMinutes: 30 });
  }
  const roomStatuses = await waitForRoom(users);
  const roomIds = new Set(roomStatuses.map((status) => String(status.room?.id ?? '')));
  if (roomIds.size !== 1 || roomIds.has('')) throw new Error('Premium users did not join one room.');
  if (!roomStatuses.every((status) => Number(status.room?.config?.roomDurationMinutes) === 30)) {
    throw new Error('Premium room duration was not persisted as 30 minutes.');
  }

  await cleanup(ids);

  // Queue priority: a premium user joining later ranks ahead of a free user
  // inside the same 15-minute pool.
  await pool.query(
    `update user_subscriptions set status='expired',expires_at=now()-interval '1 minute'
     where user_id=$1`,
    [users[0].id],
  );
  await ok('POST', '/rooms/queue', users[0].sessionId, { roomDurationMinutes: 15 });
  await sleep(100);
  await ok('POST', '/rooms/queue', users[1].sessionId, { roomDurationMinutes: 15 });

  const freeStatus = await ok('GET', '/rooms/queue', users[0].sessionId);
  const premiumStatus = await ok('GET', '/rooms/queue', users[1].sessionId);
  if (premiumStatus.premiumPriority !== true || Number(premiumStatus.position) !== 1) {
    throw new Error(`Premium priority missing: ${JSON.stringify(premiumStatus)}`);
  }
  if (freeStatus.premiumPriority !== false || Number(freeStatus.position) !== 2) {
    throw new Error(`Free queue position should be behind premium: ${JSON.stringify(freeStatus)}`);
  }

  await cleanup(ids);
  console.log('✅ MEET6 PREMIUM SUBSCRIPTION E2E PASS');
  console.log('Rules: free 30m denied → active premium 30m pool → server-persisted 30m room → premium queue priority');
}

try {
  await main();
} catch (error) {
  console.error('❌ MEET6 PREMIUM SUBSCRIPTION E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
