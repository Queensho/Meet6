import { randomUUID } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import dotenv from 'dotenv';
import Redis from 'ioredis';
import pg from 'pg';
import { io } from 'socket.io-client';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverDir = path.resolve(__dirname, '..');
const repoDir = path.resolve(serverDir, '..');

dotenv.config({ path: path.resolve(repoDir, '.env') });
dotenv.config({ path: path.resolve(serverDir, '.env'), override: false });

function envInt(name, fallback, min, max) {
  const raw = process.env[name];
  const value = raw == null || raw === '' ? fallback : Number(raw);
  if (!Number.isFinite(value)) throw new Error(`${name} must be a number.`);
  const rounded = Math.floor(value);
  if (rounded < min || rounded > max) {
    throw new Error(`${name} must be between ${min} and ${max}.`);
  }
  return rounded;
}

function envFloat(name, fallback, min, max) {
  const raw = process.env[name];
  const value = raw == null || raw === '' ? fallback : Number(raw);
  if (!Number.isFinite(value) || value < min || value > max) {
    throw new Error(`${name} must be between ${min} and ${max}.`);
  }
  return value;
}

const cliUsers = process.argv[2] ? Number(process.argv[2]) : undefined;
const USERS = cliUsers == null
  ? envInt('LOAD_USERS', 100, 6, 500)
  : Math.max(6, Math.min(500, Math.floor(cliUsers)));
const CONNECT_RAMP_MS = envInt('LOAD_CONNECT_RAMP_MS', 8_000, 0, 120_000);
const QUEUE_RAMP_MS = envInt('LOAD_QUEUE_RAMP_MS', 4_000, 0, 120_000);
const CONNECT_TIMEOUT_MS = envInt('LOAD_CONNECT_TIMEOUT_MS', 15_000, 1_000, 120_000);
const ACK_TIMEOUT_MS = envInt('LOAD_ACK_TIMEOUT_MS', 180_000, 2_000, 600_000);
const SETTLE_MS = envInt('LOAD_SETTLE_MS', 8_000, 0, 120_000);
const SESSION_TTL_SECONDS = envInt('LOAD_SESSION_TTL_SECONDS', 7_200, 300, 86_400);
const KEEP_DATA = process.env.LOAD_KEEP_DATA === '1';
const SEND_ROOM_MESSAGES = process.env.LOAD_ROOM_MESSAGES !== '0';
const FAIL_ON_THRESHOLD = process.env.LOAD_FAIL_ON_THRESHOLD !== '0';
const PHONE_PREFIX = (process.env.LOAD_PHONE_PREFIX ?? '+99988').trim();
const SOCKET_BASE = (process.env.LOAD_SOCKET_BASE
  ?? process.env.E2E_SOCKET_BASE
  ?? 'http://127.0.0.1:3100/rooms').trim();
const REPORT_PATH = process.env.LOAD_REPORT_PATH
  ? path.resolve(process.env.LOAD_REPORT_PATH)
  : path.resolve(serverDir, 'load-test-report.json');

const MAX_CONNECT_P95_MS = envInt('LOAD_MAX_CONNECT_P95_MS', 5_000, 100, 300_000);
const MAX_PING_P95_MS = envInt('LOAD_MAX_PING_P95_MS', 2_000, 50, 300_000);
const MAX_QUEUE_P95_MS = envInt('LOAD_MAX_QUEUE_P95_MS', 120_000, 500, 600_000);
const MAX_ROOM_JOIN_P95_MS = envInt('LOAD_MAX_ROOM_JOIN_P95_MS', 10_000, 100, 300_000);
const MAX_MESSAGE_P95_MS = envInt('LOAD_MAX_MESSAGE_P95_MS', 5_000, 100, 300_000);
const MIN_CONNECT_RATE = envFloat('LOAD_MIN_CONNECT_RATE', 0.99, 0, 1);

if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required.');
if (!process.env.REDIS_URL) throw new Error('REDIS_URL is required.');
if (!/^\+999\d{1,8}$/.test(PHONE_PREFIX)) {
  throw new Error('LOAD_PHONE_PREFIX must be a reserved +999... test prefix.');
}

const socketUrl = new URL(SOCKET_BASE);
const localHosts = new Set(['127.0.0.1', 'localhost', '::1']);
if (!localHosts.has(socketUrl.hostname) && process.env.LOAD_ALLOW_REMOTE !== 'YES_I_KNOW') {
  throw new Error(
    `Refusing remote load test against ${socketUrl.hostname}. `
      + 'Set LOAD_ALLOW_REMOTE=YES_I_KNOW only for an explicitly approved staging/production test window.',
  );
}

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  max: Math.min(30, Math.max(10, Math.ceil(USERS / 25))),
});
const redis = new Redis(process.env.REDIS_URL, {
  maxRetriesPerRequest: 2,
  enableReadyCheck: true,
});

const sockets = [];
const runId = `${Date.now()}-${randomUUID().slice(0, 8)}`;
const startedAt = new Date();
let syntheticUsers = [];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function nowMs() {
  return Number(process.hrtime.bigint()) / 1_000_000;
}

function percentile(values, p) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return Math.round(sorted[index] * 100) / 100;
}

function stats(values) {
  const valid = values.filter((value) => Number.isFinite(value));
  if (!valid.length) return { count: 0, min: null, avg: null, p50: null, p95: null, p99: null, max: null };
  const total = valid.reduce((sum, value) => sum + value, 0);
  return {
    count: valid.length,
    min: Math.round(Math.min(...valid) * 100) / 100,
    avg: Math.round((total / valid.length) * 100) / 100,
    p50: percentile(valid, 50),
    p95: percentile(valid, 95),
    p99: percentile(valid, 99),
    max: Math.round(Math.max(...valid) * 100) / 100,
  };
}

function log(label, value = '') {
  console.log(`\n=== ${label} ===`);
  if (value !== '') console.log(value);
}

function phoneFor(index) {
  return `${PHONE_PREFIX}${String(index + 1).padStart(7, '0')}`;
}

async function redisCleanupForUsers(users) {
  if (!users.length) return;
  for (const user of users) {
    const userId = String(user.id ?? user.user_id);
    const sessionSet = `user-sessions:${userId}`;
    const sessionIds = await redis.smembers(sessionSet).catch(() => []);
    const keys = [sessionSet, `presence:${userId}`];
    for (const sessionId of sessionIds) keys.push(`session:${sessionId}`);
    if (keys.length) await redis.del(...keys).catch(() => undefined);
  }
}

async function cleanupTestCohort() {
  const existing = await pool.query(
    `select id::text, phone_e164
     from users
     where phone_e164 like $1
     order by id asc`,
    [`${PHONE_PREFIX}%`],
  );
  if (!existing.rows.length) return;

  await redisCleanupForUsers(existing.rows);
  const ids = existing.rows.map((row) => row.id);
  const roomResult = await pool.query(
    `select distinct room_id::text
     from room_members
     where user_id = any($1::bigint[])`,
    [ids],
  );
  const roomIds = roomResult.rows.map((row) => row.room_id);
  if (roomIds.length) {
    await pool.query('delete from rooms where id = any($1::bigint[])', [roomIds]);
  }
  await pool.query('delete from users where id = any($1::bigint[])', [ids]);
}

async function seedUsers() {
  await cleanupTestCohort();

  const phones = Array.from({ length: USERS }, (_, index) => phoneFor(index));
  await pool.query(
    `insert into users(phone_e164, status)
     select phone, 'active'
     from unnest($1::text[]) as t(phone)
     on conflict(phone_e164) do update set status='active', updated_at=now()`,
    [phones],
  );

  await pool.query(
    `insert into profiles(
       user_id, display_name, birth_date, gender, bio, city, country,
       latitude, longitude, interests, photo_urls, profile_completed
     )
     select u.id,
            'Load ' || right(u.phone_e164, 5),
            date '1996-06-15',
            case when mod(u.id, 2)=0 then 'Kadın' else 'Erkek' end,
            'Meet6 isolated load-test account',
            'LOAD_TEST',
            'LOAD_TEST',
            84.500000,
            0.000000,
            array['load-test'],
            array['https://example.invalid/meet6-load-test.png'],
            true
     from users u
     where u.phone_e164 = any($1::text[])
     on conflict(user_id) do update set
       display_name=excluded.display_name,
       birth_date=excluded.birth_date,
       gender=excluded.gender,
       bio=excluded.bio,
       city=excluded.city,
       country=excluded.country,
       latitude=excluded.latitude,
       longitude=excluded.longitude,
       interests=excluded.interests,
       photo_urls=excluded.photo_urls,
       profile_completed=true,
       updated_at=now()`,
    [phones],
  );

  await pool.query(
    `insert into matching_preferences(
       user_id, looking_for, min_age, max_age, distance_km, purpose
     )
     select u.id, 'Herkes', 18, 65, 1, 'LOAD_TEST'
     from users u
     where u.phone_e164 = any($1::text[])
     on conflict(user_id) do update set
       looking_for='Herkes',
       min_age=18,
       max_age=65,
       distance_km=1,
       purpose='LOAD_TEST',
       updated_at=now()`,
    [phones],
  );

  await pool.query(
    `insert into user_settings(
       user_id, notifications_enabled, room_reminders, show_online,
       precise_location, vibration, allow_room_invites,
       allow_private_messages, hide_exact_distance, read_receipts
     )
     select u.id, false, false, true, false, false, true, true, true, true
     from users u
     where u.phone_e164 = any($1::text[])
     on conflict(user_id) do update set
       notifications_enabled=false,
       room_reminders=false,
       show_online=true,
       precise_location=false,
       vibration=false,
       allow_room_invites=true,
       allow_private_messages=true,
       hide_exact_distance=true,
       read_receipts=true,
       updated_at=now()`,
    [phones],
  );

  const result = await pool.query(
    `select id::text, phone_e164
     from users
     where phone_e164 = any($1::text[])
     order by phone_e164 asc`,
    [phones],
  );
  if (result.rows.length !== USERS) {
    throw new Error(`Seeded ${result.rows.length}/${USERS} synthetic users.`);
  }

  const pipeline = redis.pipeline();
  syntheticUsers = result.rows.map((row, index) => {
    const sessionId = `load-${runId}-${index}-${randomUUID()}`;
    pipeline
      .set(`session:${sessionId}`, row.id, 'EX', SESSION_TTL_SECONDS)
      .sadd(`user-sessions:${row.id}`, sessionId)
      .expire(`user-sessions:${row.id}`, SESSION_TTL_SECONDS);
    return {
      index,
      userId: row.id,
      phone: row.phone_e164,
      sessionId,
      socket: null,
      connectMs: null,
      pingMs: null,
      queueMs: null,
      roomJoinMs: null,
      matchedAtMs: null,
      roomId: null,
      errors: [],
    };
  });
  await pipeline.exec();
  return syntheticUsers;
}

function emitAck(socket, event, payload = {}, timeoutMs = ACK_TIMEOUT_MS) {
  const started = nowMs();
  return new Promise((resolve, reject) => {
    socket.timeout(timeoutMs).emit(event, payload, (error, response) => {
      const elapsed = nowMs() - started;
      if (error) {
        reject(Object.assign(new Error(`${event} ack timeout/error: ${error.message ?? error}`), { elapsed }));
        return;
      }
      if (response?.ok === false) {
        reject(Object.assign(new Error(`${event}: ${response.error ?? 'operation failed'}`), { elapsed, response }));
        return;
      }
      resolve({ response: response ?? {}, elapsed });
    });
  });
}

async function connectUser(user, testStartedMs) {
  const started = nowMs();
  return new Promise((resolve, reject) => {
    const socket = io(SOCKET_BASE, {
      auth: { token: user.sessionId },
      transports: ['websocket'],
      reconnection: false,
      timeout: CONNECT_TIMEOUT_MS,
      forceNew: true,
    });
    sockets.push(socket);
    user.socket = socket;

    const timer = setTimeout(() => {
      cleanup();
      reject(new Error(`server:ready timeout for ${user.phone}`));
    }, CONNECT_TIMEOUT_MS);

    const cleanup = () => {
      clearTimeout(timer);
      socket.off('server:ready', onReady);
      socket.off('connect_error', onConnectError);
      socket.off('auth:error', onAuthError);
    };

    const fail = (error) => {
      cleanup();
      try { socket.disconnect(); } catch (_) {}
      reject(error instanceof Error ? error : new Error(String(error)));
    };

    const onConnectError = (error) => fail(new Error(`connect_error ${user.phone}: ${error.message ?? error}`));
    const onAuthError = (data) => fail(new Error(`auth:error ${user.phone}: ${data?.message ?? 'unknown'}`));
    const onReady = (data) => {
      if (String(data?.userId) !== String(user.userId)) return;
      cleanup();
      user.connectMs = nowMs() - started;
      resolve();
    };

    socket.on('queue:matched', (data) => {
      const roomId = data?.room?.id?.toString();
      if (roomId && !user.roomId) {
        user.roomId = roomId;
        user.matchedAtMs = nowMs() - testStartedMs;
      }
    });
    socket.once('server:ready', onReady);
    socket.once('connect_error', onConnectError);
    socket.once('auth:error', onAuthError);
  });
}

async function rampStart(items, rampMs, worker) {
  const tasks = [];
  const spacing = items.length <= 1 ? 0 : rampMs / (items.length - 1);
  for (const item of items) {
    tasks.push(worker(item));
    if (spacing > 0) await sleep(spacing);
  }
  return Promise.allSettled(tasks);
}

async function pingUsers(users) {
  await Promise.all(users.map(async (user) => {
    if (!user.socket?.connected) return;
    try {
      const { elapsed } = await emitAck(user.socket, 'ping', { runId, index: user.index }, 15_000);
      user.pingMs = elapsed;
    } catch (error) {
      user.errors.push(`ping: ${error.message ?? error}`);
    }
  }));
}

async function joinQueue(user, testStartedMs) {
  if (!user.socket?.connected) throw new Error('socket not connected');
  const { response, elapsed } = await emitAck(user.socket, 'queue:join');
  user.queueMs = elapsed;
  if (response?.state === 'room' && response?.room?.id != null) {
    user.roomId ??= response.room.id.toString();
    user.matchedAtMs ??= nowMs() - testStartedMs;
  }
}

async function joinMatchedRooms(users) {
  await Promise.all(users.map(async (user) => {
    if (!user.roomId || !user.socket?.connected) return;
    try {
      const { elapsed } = await emitAck(user.socket, 'room:join', { roomId: user.roomId });
      user.roomJoinMs = elapsed;
    } catch (error) {
      user.errors.push(`room:join: ${error.message ?? error}`);
    }
  }));
}

async function roomMessageProbe(users) {
  if (!SEND_ROOM_MESSAGES) return [];
  const groups = new Map();
  for (const user of users) {
    if (!user.roomId || !user.socket?.connected) continue;
    const group = groups.get(user.roomId) ?? [];
    group.push(user);
    groups.set(user.roomId, group);
  }

  const latencies = [];
  await Promise.all([...groups.entries()].map(async ([roomId, members]) => {
    if (members.length < 2) return;
    const sender = members[0];
    const receiver = members[1];
    const body = `load-${runId}-${roomId}`;
    const started = nowMs();

    const seen = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        receiver.socket.off('room:message', handler);
        reject(new Error(`room:message timeout room=${roomId}`));
      }, Math.min(ACK_TIMEOUT_MS, 30_000));
      const handler = (event) => {
        if (String(event?.roomId) !== String(roomId)) return;
        if (String(event?.message?.body) !== body) return;
        clearTimeout(timer);
        receiver.socket.off('room:message', handler);
        resolve(nowMs() - started);
      };
      receiver.socket.on('room:message', handler);
    });

    try {
      await emitAck(sender.socket, 'room:send', { roomId, body }, 30_000);
      latencies.push(await seen);
    } catch (error) {
      sender.errors.push(`room:message probe: ${error.message ?? error}`);
    }
  }));
  return latencies;
}

async function databaseSnapshot() {
  const settings = await pool.query(
    `select minimum_room_users, maintenance_mode
     from app_runtime_settings
     where id=1`,
  );
  const cohort = await pool.query(
    `select
       count(distinct u.id)::int as users,
       count(distinct rm.user_id) filter (where r.status in ('active','selection'))::int as matched_users,
       count(distinct r.id) filter (where r.status in ('active','selection'))::int as rooms,
       count(distinct q.user_id)::int as queued_users
     from users u
     left join room_members rm on rm.user_id=u.id
     left join rooms r on r.id=rm.room_id
     left join matchmaking_queue q on q.user_id=u.id
     where u.phone_e164 like $1`,
    [`${PHONE_PREFIX}%`],
  );
  const pgConnections = await pool.query(
    `select count(*)::int as total,
            count(*) filter (where state='active')::int as active
     from pg_stat_activity
     where datname=current_database()`,
  );
  return {
    settings: settings.rows[0] ?? {},
    cohort: cohort.rows[0] ?? {},
    postgresConnections: pgConnections.rows[0] ?? {},
  };
}

function thresholdFailures(report) {
  const failures = [];
  const { metrics, result } = report;
  if (result.connectRate < MIN_CONNECT_RATE) {
    failures.push(`connect rate ${(result.connectRate * 100).toFixed(2)}% < ${(MIN_CONNECT_RATE * 100).toFixed(2)}%`);
  }
  if (metrics.connect.p95 != null && metrics.connect.p95 > MAX_CONNECT_P95_MS) {
    failures.push(`connect p95 ${metrics.connect.p95}ms > ${MAX_CONNECT_P95_MS}ms`);
  }
  if (metrics.ping.p95 != null && metrics.ping.p95 > MAX_PING_P95_MS) {
    failures.push(`ping p95 ${metrics.ping.p95}ms > ${MAX_PING_P95_MS}ms`);
  }
  if (metrics.queueJoin.p95 != null && metrics.queueJoin.p95 > MAX_QUEUE_P95_MS) {
    failures.push(`queue:join p95 ${metrics.queueJoin.p95}ms > ${MAX_QUEUE_P95_MS}ms`);
  }
  if (metrics.roomJoin.p95 != null && metrics.roomJoin.p95 > MAX_ROOM_JOIN_P95_MS) {
    failures.push(`room:join p95 ${metrics.roomJoin.p95}ms > ${MAX_ROOM_JOIN_P95_MS}ms`);
  }
  if (metrics.roomMessage.p95 != null && metrics.roomMessage.p95 > MAX_MESSAGE_P95_MS) {
    failures.push(`room message p95 ${metrics.roomMessage.p95}ms > ${MAX_MESSAGE_P95_MS}ms`);
  }
  if (result.matchedUsers < result.expectedMatchedUsers) {
    failures.push(`matched users ${result.matchedUsers} < expected ${result.expectedMatchedUsers}`);
  }
  if (result.rooms < result.expectedRooms) {
    failures.push(`rooms ${result.rooms} < expected ${result.expectedRooms}`);
  }
  return failures;
}

async function writeReport(report) {
  await fs.mkdir(path.dirname(REPORT_PATH), { recursive: true });
  await fs.writeFile(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
}

async function main() {
  const testStartedMs = nowMs();
  log('MEET6 LOAD TEST', [
    `runId=${runId}`,
    `users=${USERS}`,
    `socket=${SOCKET_BASE}`,
    `connectRampMs=${CONNECT_RAMP_MS}`,
    `queueRampMs=${QUEUE_RAMP_MS}`,
    `roomMessages=${SEND_ROOM_MESSAGES}`,
    `keepData=${KEEP_DATA}`,
  ].join('\n'));

  const runtime = await pool.query(
    `select minimum_room_users, maintenance_mode
     from app_runtime_settings where id=1`,
  );
  const roomSize = Number(runtime.rows[0]?.minimum_room_users ?? 6);
  if (runtime.rows[0]?.maintenance_mode === true) {
    throw new Error('Runtime maintenance mode is enabled; matchmaking load test cannot run.');
  }
  if (USERS < roomSize) throw new Error(`LOAD_USERS must be at least runtime room size ${roomSize}.`);

  log('SEED', `Creating ${USERS} isolated synthetic profiles at latitude 84.5...`);
  const users = await seedUsers();

  log('WEBSOCKET CONNECT', `Ramping ${USERS} authenticated clients over ${CONNECT_RAMP_MS} ms...`);
  const connectResults = await rampStart(users, CONNECT_RAMP_MS, async (user) => {
    try {
      await connectUser(user, testStartedMs);
    } catch (error) {
      user.errors.push(`connect: ${error.message ?? error}`);
      throw error;
    }
  });
  const connectedUsers = users.filter((user) => user.socket?.connected && user.connectMs != null);
  const connectFailures = connectResults.filter((item) => item.status === 'rejected').length;
  log('CONNECTED', `${connectedUsers.length}/${USERS} ready; failures=${connectFailures}`);

  log('PING', 'Sending concurrent Socket.IO ack pings...');
  await pingUsers(connectedUsers);

  log('MATCHMAKING', `Ramping queue:join across ${connectedUsers.length} clients over ${QUEUE_RAMP_MS} ms...`);
  await rampStart(connectedUsers, QUEUE_RAMP_MS, async (user) => {
    try {
      await joinQueue(user, testStartedMs);
    } catch (error) {
      user.errors.push(`queue:join: ${error.message ?? error}`);
    }
  });

  if (SETTLE_MS) await sleep(SETTLE_MS);

  log('ROOM JOIN', 'Joining matched room channels concurrently...');
  await joinMatchedRooms(connectedUsers);

  log('ROOM MESSAGE PROBE', SEND_ROOM_MESSAGES
    ? 'Sending one real WebSocket message per matched room...'
    : 'disabled');
  const roomMessageLatencies = await roomMessageProbe(connectedUsers);

  const snapshot = await databaseSnapshot();
  const expectedRooms = Math.floor(USERS / roomSize);
  const expectedMatchedUsers = expectedRooms * roomSize;
  const matchedUsers = Number(snapshot.cohort.matched_users ?? 0);
  const rooms = Number(snapshot.cohort.rooms ?? 0);
  const queuedUsers = Number(snapshot.cohort.queued_users ?? 0);
  const errors = users.flatMap((user) => user.errors.map((error) => ({
    index: user.index,
    phone: user.phone,
    error,
  })));

  const finishedAt = new Date();
  const report = {
    runId,
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationMs: Math.round(nowMs() - testStartedMs),
    config: {
      users: USERS,
      roomSize,
      socketBase: SOCKET_BASE,
      connectRampMs: CONNECT_RAMP_MS,
      queueRampMs: QUEUE_RAMP_MS,
      settleMs: SETTLE_MS,
      ackTimeoutMs: ACK_TIMEOUT_MS,
      sendRoomMessages: SEND_ROOM_MESSAGES,
      thresholds: {
        minConnectRate: MIN_CONNECT_RATE,
        maxConnectP95Ms: MAX_CONNECT_P95_MS,
        maxPingP95Ms: MAX_PING_P95_MS,
        maxQueueP95Ms: MAX_QUEUE_P95_MS,
        maxRoomJoinP95Ms: MAX_ROOM_JOIN_P95_MS,
        maxRoomMessageP95Ms: MAX_MESSAGE_P95_MS,
      },
    },
    metrics: {
      connect: stats(users.map((user) => user.connectMs)),
      ping: stats(users.map((user) => user.pingMs)),
      queueJoin: stats(users.map((user) => user.queueMs)),
      matchedAt: stats(users.map((user) => user.matchedAtMs)),
      roomJoin: stats(users.map((user) => user.roomJoinMs)),
      roomMessage: stats(roomMessageLatencies),
    },
    result: {
      connectedUsers: connectedUsers.length,
      connectRate: USERS === 0 ? 0 : connectedUsers.length / USERS,
      expectedRooms,
      rooms,
      expectedMatchedUsers,
      matchedUsers,
      queuedUsers,
      errorCount: errors.length,
    },
    database: snapshot,
    clientProcess: {
      rssMb: Math.round(process.memoryUsage().rss / 1024 / 1024),
      heapUsedMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
    },
    errors: errors.slice(0, 100),
  };

  report.thresholdFailures = thresholdFailures(report);
  report.pass = report.thresholdFailures.length === 0;
  await writeReport(report);

  log('RESULT', JSON.stringify({
    pass: report.pass,
    durationMs: report.durationMs,
    result: report.result,
    metrics: report.metrics,
    thresholdFailures: report.thresholdFailures,
    reportPath: REPORT_PATH,
  }, null, 2));

  if (!report.pass && FAIL_ON_THRESHOLD) {
    process.exitCode = 1;
  }
}

try {
  await main();
} catch (error) {
  console.error('\n❌ MEET6 LOAD TEST FAILED TO COMPLETE');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  for (const socket of sockets) {
    try { socket.disconnect(); } catch (_) {}
  }
  await sleep(150);

  if (!KEEP_DATA) {
    try {
      await cleanupTestCohort();
      console.log('\nSynthetic load-test cohort cleaned up.');
    } catch (error) {
      console.error(`Load-test cleanup failed: ${error?.message ?? error}`);
      process.exitCode = 1;
    }
  } else {
    console.log(`\nLOAD_KEEP_DATA=1: synthetic cohort retained with prefix ${PHONE_PREFIX}.`);
  }

  await pool.end().catch(() => undefined);
  redis.disconnect();
}
