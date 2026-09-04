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

async function activeSession(userId) {
  const ids = await redis.smembers(`user-sessions:${userId}`);
  for (const id of ids) {
    const owner = await redis.get(`session:${id}`);
    if (String(owner) === String(userId)) return id;
  }
  throw new Error(`No active session for CI user ${userId}.`);
}

async function request(method, pathName, sessionId) {
  const response = await fetch(`${API}${pathName}`, {
    method,
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${sessionId}`,
    },
  });
  const text = await response.text();
  let data = {};
  if (text) {
    try { data = JSON.parse(text); } catch { data = { raw: text }; }
  }
  return { response, data };
}

async function ok(method, pathName, sessionId) {
  const result = await request(method, pathName, sessionId);
  if (!result.response.ok) {
    throw new Error(`${method} ${pathName} -> ${result.response.status}: ${result.data.message ?? result.data.raw ?? result.response.statusText}`);
  }
  return result.data;
}

async function cleanup(ids) {
  await pool.query('delete from voice_matchmaking_queue where user_id=any($1::bigint[])', [ids]);
  await pool.query(
    `update rooms r set status='closed',closed_at=coalesce(closed_at,now())
     where r.id in (select distinct room_id from room_members where user_id=any($1::bigint[]))`,
    [ids],
  );
  await pool.query(
    `update room_members set left_at=coalesce(left_at,now())
     where user_id=any($1::bigint[])`,
    [ids],
  );
  await pool.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [ids]);
}

async function main() {
  const result = await pool.query(
    `select id::text,phone_e164 from users
     where phone_e164=any($1::text[]) order by phone_e164 asc`,
    [TEST_PHONES],
  );
  if (result.rows.length !== 6) throw new Error(`Expected 6 E2E users, found ${result.rows.length}.`);

  const users = [];
  for (const row of result.rows) users.push({ ...row, sessionId: await activeSession(row.id) });
  const ids = users.map((user) => user.id);

  await cleanup(ids);
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

  // A free account cannot enter the voice matchmaking pool.
  await pool.query('delete from user_subscriptions where user_id=any($1::bigint[])', [ids]);
  const denied = await request('POST', '/voice-rooms/queue', users[0].sessionId);
  if (denied.response.status !== 403) {
    throw new Error(`Expected free voice queue request to be 403, got ${denied.response.status}.`);
  }

  // Grant all six CI users active Premium and form one isolated voice room.
  for (const user of users) {
    await pool.query(
      `insert into user_subscriptions(user_id,status,expires_at,will_renew,product_id,store)
       values($1,'active',now()+interval '30 days',true,'meet6_premium_voice_ci','PLAY_STORE')
       on conflict(user_id) do update set
         status='active',expires_at=excluded.expires_at,will_renew=true,
         product_id=excluded.product_id,store=excluded.store,updated_at=now()`,
      [user.id],
    );
  }

  for (const user of users) {
    await ok('POST', '/voice-rooms/queue', user.sessionId);
  }

  const statuses = await Promise.all(
    users.map((user) => ok('GET', '/voice-rooms/queue', user.sessionId)),
  );
  if (!statuses.every((status) => status.state === 'room')) {
    throw new Error(`Expected every Premium user in voice room: ${JSON.stringify(statuses)}`);
  }
  const roomIds = new Set(statuses.map((status) => String(status.room?.id ?? '')));
  if (roomIds.size !== 1 || roomIds.has('')) throw new Error('Voice users were not grouped into one room.');
  const roomId = [...roomIds][0];

  const roomResult = await pool.query(
    'select room_mode,room_duration_minutes from rooms where id=$1',
    [roomId],
  );
  if (roomResult.rows[0]?.room_mode !== 'voice') throw new Error('Created room is not marked voice.');
  if (Number(roomResult.rows[0]?.room_duration_minutes) !== 30) {
    throw new Error('Premium voice room duration must be 30 minutes.');
  }

  const queueCount = await pool.query(
    'select count(*)::int as count from voice_matchmaking_queue where user_id=any($1::bigint[])',
    [ids],
  );
  if (Number(queueCount.rows[0]?.count) !== 0) throw new Error('Matched voice users remained queued.');

  // CI intentionally has no LiveKit production credential. Reaching 503 proves
  // membership + Premium authorization passed before provider configuration.
  const tokenResult = await request('POST', `/voice-rooms/${roomId}/token`, users[0].sessionId);
  if (tokenResult.response.status !== 503) {
    throw new Error(`Expected unconfigured LiveKit token request to return 503 in CI, got ${tokenResult.response.status}.`);
  }

  await cleanup(ids);
  console.log('✅ MEET6 PREMIUM VOICE ROOM E2E PASS');
  console.log('Rules: free denied → six Premium users → isolated voice room → 30m duration → token remains server-gated');
}

try {
  await main();
} catch (error) {
  console.error('❌ MEET6 PREMIUM VOICE ROOM E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
