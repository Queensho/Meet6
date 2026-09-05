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

async function request(method, pathName, sessionId, body) {
  const response = await fetch(`${API}${pathName}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${sessionId}`,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = {};
  if (text) {
    try { data = JSON.parse(text); } catch { data = { raw: text }; }
  }
  return { response, data };
}

async function ok(method, pathName, sessionId, body) {
  const result = await request(method, pathName, sessionId, body);
  if (!result.response.ok) {
    throw new Error(`${method} ${pathName} -> ${result.response.status}: ${result.data.message ?? result.data.raw ?? result.response.statusText}`);
  }
  return result.data;
}

async function cleanup(ids) {
  await pool.query('delete from voice_matchmaking_queue where user_id=any($1::bigint[])', [ids]);
  await pool.query(
    `delete from voice_preview_decisions
     where room_id in (select distinct room_id from room_members where user_id=any($1::bigint[]))`,
    [ids],
  ).catch(() => undefined);
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

  await pool.query('delete from user_subscriptions where user_id=any($1::bigint[])', [ids]);
  const denied = await request('POST', '/voice-rooms/queue', users[0].sessionId);
  if (denied.response.status !== 403) {
    throw new Error(`Expected free voice queue request to be 403, got ${denied.response.status}.`);
  }

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
    throw new Error(`Expected every Premium user in one-to-one voice match: ${JSON.stringify(statuses)}`);
  }

  const roomIds = statuses.map((status) => String(status.room?.id ?? ''));
  if (roomIds.some((id) => !id)) throw new Error('One or more voice users have no room id.');
  const uniqueRoomIds = [...new Set(roomIds)];
  if (uniqueRoomIds.length !== 3) {
    throw new Error(`Expected 3 one-to-one voice rooms from 6 users, found ${uniqueRoomIds.length}.`);
  }

  for (const roomId of uniqueRoomIds) {
    const roomResult = await pool.query(
      `select r.room_mode,r.room_duration_minutes,r.voice_stage,r.extended,
              extract(epoch from (r.ends_at-now()))::int as seconds_left,
              (select count(*)::int from room_members rm
               where rm.room_id=r.id and rm.admin_removed_at is null) as member_count
       from rooms r where r.id=$1`,
      [roomId],
    );
    const row = roomResult.rows[0];
    if (row?.room_mode !== 'voice') throw new Error(`Room ${roomId} is not marked voice.`);
    if (row?.voice_stage !== 'preview') throw new Error(`Room ${roomId} did not start in preview stage.`);
    if (row?.extended !== true) throw new Error(`Room ${roomId} preview must suppress extension voting.`);
    if (Number(row?.room_duration_minutes) !== 15) {
      throw new Error(`Premium one-to-one voice room ${roomId} must reserve a 15 minute main call.`);
    }
    if (Number(row?.member_count) !== 2) {
      throw new Error(`Premium one-to-one voice room ${roomId} must contain exactly 2 users.`);
    }
    const secondsLeft = Number(row?.seconds_left ?? 0);
    if (secondsLeft < 35 || secondsLeft > 45) {
      throw new Error(`Preview room ${roomId} should start near 45 seconds, got ${secondsLeft}.`);
    }
  }

  const firstRoomId = uniqueRoomIds[0];
  const firstPair = users.filter((_, index) => roomIds[index] === firstRoomId);
  if (firstPair.length !== 2) throw new Error('Could not resolve first preview pair.');

  const initialPreview = await ok('GET', `/voice-rooms/${firstRoomId}/preview`, firstPair[0].sessionId);
  if (initialPreview.phase !== 'preview' || initialPreview.decisionOpen !== false) {
    throw new Error(`Unexpected initial preview state: ${JSON.stringify(initialPreview)}`);
  }

  // Fast-forward the 45 second preview without slowing CI down.
  await pool.query(`update rooms set ends_at=now()-interval '1 second' where id=$1`, [firstRoomId]);
  const decisionState = await ok('GET', `/voice-rooms/${firstRoomId}/preview`, firstPair[0].sessionId);
  if (decisionState.phase !== 'preview' || decisionState.decisionOpen !== true) {
    throw new Error(`Preview did not enter hidden decision stage: ${JSON.stringify(decisionState)}`);
  }

  const tokenDuringDecision = await request('POST', `/voice-rooms/${firstRoomId}/token`, firstPair[0].sessionId);
  if (tokenDuringDecision.response.status !== 400) {
    throw new Error(`Expected audio token to be blocked during preview decision, got ${tokenDuringDecision.response.status}.`);
  }

  const firstDecision = await ok(
    'PUT',
    `/voice-rooms/${firstRoomId}/preview-decision`,
    firstPair[0].sessionId,
    { continue: true },
  );
  if (firstDecision.outcome !== 'pending') {
    throw new Error(`First hidden continue should wait for partner: ${JSON.stringify(firstDecision)}`);
  }

  const secondDecision = await ok(
    'PUT',
    `/voice-rooms/${firstRoomId}/preview-decision`,
    firstPair[1].sessionId,
    { continue: true },
  );
  if (secondDecision.outcome !== 'continued') {
    throw new Error(`Mutual continue did not start main call: ${JSON.stringify(secondDecision)}`);
  }

  const mainRoom = await pool.query(
    `select status,voice_stage,extended,
            extract(epoch from (ends_at-now()))::int as seconds_left
     from rooms where id=$1`,
    [firstRoomId],
  );
  const main = mainRoom.rows[0];
  if (main?.status !== 'active' || main?.voice_stage !== 'main' || main?.extended !== false) {
    throw new Error(`Main call state invalid: ${JSON.stringify(main)}`);
  }
  if (Number(main?.seconds_left ?? 0) < 890 || Number(main?.seconds_left ?? 0) > 900) {
    throw new Error(`Main call must restart at 15 minutes: ${JSON.stringify(main)}`);
  }

  const tokenResult = await request('POST', `/voice-rooms/${firstRoomId}/token`, firstPair[0].sessionId);
  if (tokenResult.response.status !== 503) {
    throw new Error(`Expected unconfigured LiveKit token request to return 503 after mutual continue, got ${tokenResult.response.status}.`);
  }

  // A single Skip must end a different preview without revealing who skipped.
  const skipRoomId = uniqueRoomIds[1];
  const skipPair = users.filter((_, index) => roomIds[index] === skipRoomId);
  if (skipPair.length !== 2) throw new Error('Could not resolve skip preview pair.');
  await pool.query(`update rooms set ends_at=now()-interval '1 second' where id=$1`, [skipRoomId]);
  await ok('GET', `/voice-rooms/${skipRoomId}/preview`, skipPair[0].sessionId);
  const skipped = await ok(
    'PUT',
    `/voice-rooms/${skipRoomId}/preview-decision`,
    skipPair[0].sessionId,
    { continue: false },
  );
  if (skipped.outcome !== 'ended') throw new Error(`Skip did not close preview: ${JSON.stringify(skipped)}`);
  const closed = await pool.query('select status from rooms where id=$1', [skipRoomId]);
  if (closed.rows[0]?.status !== 'closed') throw new Error('Skipped preview room stayed open.');

  const queueCount = await pool.query(
    'select count(*)::int as count from voice_matchmaking_queue where user_id=any($1::bigint[])',
    [ids],
  );
  if (Number(queueCount.rows[0]?.count) !== 0) throw new Error('Matched voice users remained queued.');

  await cleanup(ids);
  console.log('✅ MEET6 PREMIUM 45S PREVIEW + ONE-TO-ONE VOICE E2E PASS');
  console.log('Rules: free denied → 3 pairs → 45s preview → hidden decision → mutual continue starts fresh 15m → skip closes privately');
}

try {
  await main();
} catch (error) {
  console.error('❌ MEET6 PREMIUM 45S PREVIEW + ONE-TO-ONE VOICE E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
