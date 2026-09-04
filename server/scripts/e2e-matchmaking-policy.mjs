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

async function jsonRequest(method, urlPath, sessionId) {
  const response = await fetch(`${API}${urlPath}`, {
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
  if (!response.ok) {
    throw new Error(`${method} ${urlPath} -> ${response.status}: ${data.message ?? data.raw ?? response.statusText}`);
  }
  return data;
}

async function queueAll(users) {
  for (const user of users) {
    await jsonRequest('POST', '/rooms/queue', user.sessionId);
  }
  return Promise.all(users.map((user) => jsonRequest('GET', '/rooms/queue', user.sessionId)));
}

async function cancelAll(users) {
  await Promise.all(users.map((user) => jsonRequest('DELETE', '/rooms/queue', user.sessionId)));
}

async function expectAllQueued(users, label) {
  const statuses = await queueAll(users);
  if (statuses.some((status) => status.state === 'room')) {
    throw new Error(`${label}: a forbidden six-person room was created.`);
  }
  if (!statuses.every((status) => status.state === 'queued')) {
    throw new Error(`${label}: expected all users to remain queued.`);
  }
  const policy = statuses[0]?.filters;
  if (policy?.preferencesRelaxed !== false || policy?.blockAndReport !== 'permanent') {
    throw new Error(`${label}: strict waiting policy metadata is missing.`);
  }
  await cancelAll(users);
}

async function waitForOneRoom(users, timeoutMs = 6000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const statuses = await Promise.all(
      users.map((user) => jsonRequest('GET', '/rooms/queue', user.sessionId)),
    );
    if (statuses.every((status) => status.state === 'room')) {
      const ids = new Set(statuses.map((status) => String(status.room?.id ?? '')));
      if (ids.size !== 1 || ids.has('')) {
        throw new Error(`Control room mismatch: ${[...ids].join(', ')}`);
      }
      return [...ids][0];
    }
    await sleep(250);
  }
  throw new Error('Control group did not form after hard exclusions were removed.');
}

async function main() {
  const result = await pool.query(
    `select id::text, phone_e164
     from users
     where phone_e164 = any($1::text[])
     order by phone_e164 asc`,
    [TEST_PHONES],
  );
  if (result.rows.length !== 6) {
    throw new Error(`Expected 6 E2E users, found ${result.rows.length}.`);
  }

  const users = [];
  for (const row of result.rows) {
    users.push({ ...row, sessionId: await activeSession(row.id) });
  }
  const ids = users.map((user) => user.id);

  // Finish the product-E2E room so these users can queue again.
  await pool.query(
    `update rooms r
     set status='closed', closed_at=coalesce(closed_at, now())
     where r.id in (
       select distinct room_id from room_members where user_id = any($1::bigint[])
     )`,
    [ids],
  );
  await pool.query(
    `update room_members
     set left_at=coalesce(left_at, now())
     where user_id = any($1::bigint[])`,
    [ids],
  );
  await pool.query('delete from matchmaking_queue where user_id = any($1::bigint[])', [ids]);

  // Rule 1: the exact same six people cannot immediately form another room.
  await expectAllQueued(users, 'recent-room-repeat');

  // Move room history outside the 24-hour window. The active Aslı/Mert match
  // must still keep the six-person set from forming because one forbidden pair
  // is enough to invalidate a group.
  await pool.query(
    `update rooms
     set started_at = now() - interval '2 days'
     where id in (select distinct room_id from room_members where user_id = any($1::bigint[]))`,
    [ids],
  );
  await expectAllQueued(users, 'active-match-exclusion');

  // End and age the match. Historical matches remain a permanent exclusion:
  // elapsed time never makes that pair eligible for the same room again.
  await pool.query(
    `update matches
     set unmatched_at=coalesce(unmatched_at, now()),
         created_at=now() - interval '8 days'
     where user_a_id = any($1::bigint[]) and user_b_id = any($1::bigint[])`,
    [ids],
  );
  await expectAllQueued(users, 'historical-match-exclusion');

  // Test-fixture cleanup only: remove the historical match so report/block
  // rules and the final eligible control can be tested independently. Real
  // application code never deletes a match to make a pair eligible again.
  await pool.query(
    `delete from matches
     where user_a_id = any($1::bigint[]) and user_b_id = any($1::bigint[])`,
    [ids],
  );

  // Rule 2: any historical report permanently separates the pair.
  await pool.query(
    `insert into reports(reporter_user_id, reported_user_id, reason, detail)
     values($1,$2,'ci-policy-test','matchmaking separation test')`,
    [users[2].id, users[3].id],
  );
  await expectAllQueued(users, 'report-exclusion');
  await pool.query(
    `delete from reports
     where reporter_user_id=$1 and reported_user_id=$2 and reason='ci-policy-test'`,
    [users[2].id, users[3].id],
  );

  // Rule 3: a block is also a permanent hard exclusion.
  await pool.query(
    `insert into blocked_users(blocker_user_id, blocked_user_id)
     values($1,$2) on conflict do nothing`,
    [users[4].id, users[5].id],
  );
  await expectAllQueued(users, 'block-exclusion');
  await pool.query(
    'delete from blocked_users where blocker_user_id=$1 and blocked_user_id=$2',
    [users[4].id, users[5].id],
  );

  // Control: with the test-only historical-match fixture removed and no
  // report/block separation, the otherwise compatible six can form a room.
  await queueAll(users);
  const roomId = await waitForOneRoom(users);

  console.log('✅ MEET6 MATCHMAKING POLICY E2E PASS');
  console.log(`controlRoomId=${roomId}`);
  console.log('Rules: recent-room cooldown → permanent historical-match exclusion → permanent report/block separation → strict wait → eligible isolated control room');
}

try {
  await main();
} catch (error) {
  console.error('❌ MEET6 MATCHMAKING POLICY E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
