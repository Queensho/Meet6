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
const TEST_PHONES = [
  '+905550060001', '+905550060002', '+905550060003',
  '+905550060004', '+905550060005', '+905550060006',
];
const EXTRA_PHONE = '+905550069999';

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
  throw new Error(`No active session for E2E user ${userId}.`);
}

async function request(method, pathName, sessionId, body) {
  const response = await fetch(`${API}${pathName}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      Authorization: `Bearer ${sessionId}`,
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = {};
  if (text) {
    try { data = JSON.parse(text); } catch { data = { raw: text }; }
  }
  if (!response.ok) {
    throw new Error(`${method} ${pathName} -> ${response.status}: ${data.message ?? data.raw ?? response.statusText}`);
  }
  return data;
}

async function waitFor(predicate, timeoutMs = 9000, stepMs = 400) {
  const deadline = Date.now() + timeoutMs;
  let last;
  while (Date.now() < deadline) {
    last = await predicate();
    if (last?.done) return last.value;
    await new Promise((resolve) => setTimeout(resolve, stepMs));
  }
  throw new Error(`Timed out waiting for policy condition. Last=${JSON.stringify(last)}`);
}

async function ensureExtraUser() {
  await pool.query(
    `insert into users(phone_e164,status)
     values($1,'active')
     on conflict(phone_e164) do update set status='active',updated_at=now()`,
    [EXTRA_PHONE],
  );
  const result = await pool.query(
    'select id::text from users where phone_e164=$1',
    [EXTRA_PHONE],
  );
  const userId = result.rows[0]?.id;
  if (!userId) throw new Error('Could not create extra refill E2E user.');

  await pool.query(
    `insert into profiles(
       user_id,display_name,birth_date,gender,bio,city,country,
       latitude,longitude,interests,photo_urls,profile_completed
     )
     values($1,'Refill E2E',date '1996-06-15','Erkek','Refill policy test','TEST','TEST',
            41.000000,29.000000,array['test'],array['https://example.invalid/refill.png'],true)
     on conflict(user_id) do update set
       display_name=excluded.display_name,birth_date=excluded.birth_date,gender=excluded.gender,
       latitude=excluded.latitude,longitude=excluded.longitude,profile_completed=true,updated_at=now()`,
    [userId],
  );
  await pool.query(
    `insert into matching_preferences(user_id,looking_for,min_age,max_age,distance_km,purpose)
     values($1,'Herkes',18,65,50,'REFILL_TEST')
     on conflict(user_id) do update set
       looking_for='Herkes',min_age=18,max_age=65,distance_km=50,purpose='REFILL_TEST',updated_at=now()`,
    [userId],
  );

  const oldSessions = await redis.smembers(`user-sessions:${userId}`);
  if (oldSessions.length) await redis.del(...oldSessions.map((id) => `session:${id}`));
  await redis.del(`user-sessions:${userId}`);
  const sessionId = `refill-policy-${randomUUID()}`;
  await redis
    .multi()
    .set(`session:${sessionId}`, userId, 'EX', 3600)
    .sadd(`user-sessions:${userId}`, sessionId)
    .expire(`user-sessions:${userId}`, 3600)
    .exec();
  return { id: userId, sessionId };
}

async function normalizeBaseUsers(ids) {
  await pool.query(
    `update profiles
     set latitude=41.000000,longitude=29.000000,profile_completed=true,updated_at=now()
     where user_id=any($1::bigint[])`,
    [ids],
  );
  await pool.query(
    `update matching_preferences
     set looking_for='Herkes',min_age=18,max_age=65,distance_km=50,purpose='REFILL_TEST',updated_at=now()
     where user_id=any($1::bigint[])`,
    [ids],
  );
}

async function cleanup(ids) {
  await pool.query('delete from matchmaking_queue where user_id=any($1::bigint[])', [ids]);
  await pool.query('delete from voice_matchmaking_queue where user_id=any($1::bigint[])', [ids]);
  await pool.query(
    `update rooms set status='closed',closed_at=coalesce(closed_at,now())
     where id in (select distinct room_id from room_members where user_id=any($1::bigint[]))
       and status in ('active','selection')`,
    [ids],
  );
  await pool.query(
    `update room_members set left_at=coalesce(left_at,now())
     where user_id=any($1::bigint[]) and left_at is null`,
    [ids],
  );
}

async function createTextRoom(memberIds, minutesAgo) {
  const result = await pool.query(
    `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
     values('active',now()-($1::int * interval '1 minute'),
             now()+((15-$1)::int * interval '1 minute'),15,'text')
     returning id::text,ends_at`,
    [minutesAgo],
  );
  const room = result.rows[0];
  for (const userId of memberIds) {
    await pool.query('insert into room_members(room_id,user_id) values($1,$2)', [room.id, userId]);
  }
  return room;
}

async function main() {
  const base = await pool.query(
    `select id::text,phone_e164 from users
     where phone_e164=any($1::text[]) order by phone_e164 asc`,
    [TEST_PHONES],
  );
  if (base.rows.length !== 6) throw new Error(`Expected 6 E2E users, found ${base.rows.length}.`);

  const users = [];
  for (const row of base.rows) users.push({ ...row, sessionId: await activeSession(row.id) });
  const extra = await ensureExtraUser();
  const baseIds = users.map((user) => user.id);
  const allIds = [...baseIds, extra.id];

  await cleanup(allIds);
  await normalizeBaseUsers(baseIds);

  // Keep the earlier product E2E match/private-chat state intact. The extra
  // refill user is fresh, so there are no block/report/match relations involving it.

  // 1) First five minutes: a voluntary leave opens exactly one replacement seat.
  const early = await createTextRoom(baseIds, 2);
  const earlyLeave = await request('DELETE', `/room-session/${early.id}`, users[0].sessionId);
  if (earlyLeave.left !== true || earlyLeave.refillOpen !== true) {
    throw new Error(`Expected early text leave to open refill: ${JSON.stringify(earlyLeave)}`);
  }
  const beforeRefill = await request('GET', `/rooms/${early.id}`, users[1].sessionId);
  if (Number(beforeRefill.members?.length ?? -1) !== 5) {
    throw new Error(`Expected 5 visible members after early leave, got ${beforeRefill.members?.length}.`);
  }

  await request('POST', '/rooms/queue', extra.sessionId, { roomDurationMinutes: 15 });
  const refilled = await waitFor(async () => {
    const status = await request('GET', '/rooms/queue', extra.sessionId);
    return {
      done: status.state === 'room' && String(status.room?.id ?? '') === String(early.id),
      value: status,
    };
  });
  if (String(refilled.room?.id ?? '') !== String(early.id)) {
    throw new Error(`Replacement joined wrong room: ${JSON.stringify(refilled)}`);
  }
  const earlyCount = await pool.query(
    `select count(*)::int as count
     from room_members
     where room_id=$1 and left_at is null and admin_removed_at is null`,
    [early.id],
  );
  if (Number(earlyCount.rows[0]?.count) !== 6) {
    throw new Error(`Early room was not restored to 6 active users.`);
  }

  // 2) After minute five: leaving reduces the room, but no replacement is allowed.
  await cleanup(allIds);
  const locked = await createTextRoom(baseIds, 6);
  const lateLeave = await request('DELETE', `/room-session/${locked.id}`, users[0].sessionId);
  if (lateLeave.left !== true || lateLeave.refillOpen !== false) {
    throw new Error(`Expected late text leave to keep room locked: ${JSON.stringify(lateLeave)}`);
  }
  const lockedSnapshot = await request('GET', `/rooms/${locked.id}`, users[1].sessionId);
  if (Number(lockedSnapshot.members?.length ?? -1) !== 5) {
    throw new Error(`Expected locked room to continue with 5 users.`);
  }
  await request('POST', '/rooms/queue', extra.sessionId, { roomDurationMinutes: 15 });
  await new Promise((resolve) => setTimeout(resolve, 6200));
  const lateStatus = await request('GET', '/rooms/queue', extra.sessionId);
  if (lateStatus.state === 'room' && String(lateStatus.room?.id ?? '') === String(locked.id)) {
    throw new Error('A user refilled a text room after the five-minute lock.');
  }
  const lockedCount = await pool.query(
    `select count(*)::int as count
     from room_members
     where room_id=$1 and left_at is null and admin_removed_at is null`,
    [locked.id],
  );
  if (Number(lockedCount.rows[0]?.count) !== 5) {
    throw new Error('Locked text room did not remain at five active members.');
  }

  // 3) One-to-one voice: either participant leaving closes the call for both.
  await cleanup(allIds);
  const voice = await pool.query(
    `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode,voice_stage)
     values('active',now(),now()+interval '15 minutes',15,'voice','main')
     returning id::text`,
  );
  const voiceRoomId = voice.rows[0].id;
  await pool.query('insert into room_members(room_id,user_id) values($1,$2)', [voiceRoomId, users[0].id]);
  await pool.query('insert into room_members(room_id,user_id) values($1,$2)', [voiceRoomId, users[1].id]);

  const voiceLeave = await request('DELETE', `/room-session/${voiceRoomId}`, users[0].sessionId);
  if (voiceLeave.left !== true || voiceLeave.closedForEveryone !== true) {
    throw new Error(`Voice leave did not close for both: ${JSON.stringify(voiceLeave)}`);
  }
  const voiceState = await pool.query(
    `select r.status,
            (select count(*)::int from room_members rm
             where rm.room_id=r.id and rm.left_at is null) as active_count
     from rooms r where r.id=$1`,
    [voiceRoomId],
  );
  if (voiceState.rows[0]?.status !== 'closed' || Number(voiceState.rows[0]?.active_count) !== 0) {
    throw new Error(`Voice room remained active after participant leave.`);
  }
  const otherCurrent = await request('GET', '/room-session/current', users[1].sessionId);
  if (otherCurrent.room != null) {
    throw new Error(`Peer still has an active voice room after the other participant left.`);
  }

  console.log('✅ MEET6 ROOM LEAVE + REFILL POLICY E2E PASS');
  console.log('Rules: text <5m refill to 6 → text >=5m locks and continues with 5 → voice leave closes both');

  await cleanup(allIds);
  await redis.del(`user-sessions:${extra.id}`, `session:${extra.sessionId}`).catch(() => undefined);
  await pool.query('delete from users where id=$1', [extra.id]);
}

try {
  await main();
} catch (error) {
  console.error('❌ MEET6 ROOM LEAVE + REFILL POLICY E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
