import process from 'node:process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';
import Redis from 'ioredis';
import { io } from 'socket.io-client';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverDir = path.resolve(__dirname, '..');
const repoDir = path.resolve(serverDir, '..');

dotenv.config({ path: path.resolve(repoDir, '.env') });
dotenv.config({ path: path.resolve(serverDir, '.env'), override: false });

const SOCKET_BASE = process.env.E2E_SOCKET_BASE ?? 'http://127.0.0.1:3100/rooms';
const DATABASE_URL = process.env.DATABASE_URL;
const REDIS_URL = process.env.REDIS_URL;

if (!DATABASE_URL) throw new Error('DATABASE_URL is required.');
if (!REDIS_URL) throw new Error('REDIS_URL is required.');

const pool = new pg.Pool({ connectionString: DATABASE_URL });
const redis = new Redis(REDIS_URL, { maxRetriesPerRequest: 2 });
const sockets = [];
const TEST_PHONES = ['+905550060001', '+905550060002'];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function waitEvent(socket, event, predicate = () => true, timeoutMs = 8000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off(event, handler);
      reject(new Error(`Timed out waiting for socket event ${event}`));
    }, timeoutMs);

    const handler = (data) => {
      try {
        if (!predicate(data)) return;
        clearTimeout(timer);
        socket.off(event, handler);
        resolve(data);
      } catch (error) {
        clearTimeout(timer);
        socket.off(event, handler);
        reject(error);
      }
    };

    socket.on(event, handler);
  });
}

function emitAck(socket, event, payload = {}, timeoutMs = 8000) {
  return new Promise((resolve, reject) => {
    socket.timeout(timeoutMs).emit(event, payload, (error, response) => {
      if (error) {
        reject(new Error(`${event} ack timeout/error: ${error.message ?? error}`));
        return;
      }
      if (response?.ok === false) {
        reject(new Error(`${event}: ${response.error ?? 'socket operation failed'}`));
        return;
      }
      resolve(response ?? {});
    });
  });
}

async function waitForPrivateMessageCooldown(userId, matchId) {
  const key = `private-message:${userId}:${matchId}`;
  const remainingMs = await redis.pttl(key);
  if (remainingMs > 0) {
    await sleep(remainingMs + 150);
  }
}

async function activeSession(userId) {
  const ids = await redis.smembers(`user-sessions:${userId}`);
  for (const id of ids) {
    const owner = await redis.get(`session:${id}`);
    if (String(owner) === String(userId)) return id;
  }
  throw new Error(`No active Redis session for CI user ${userId}. Run e2e:live first.`);
}

async function connectUser(user) {
  const sessionId = await activeSession(user.id);
  const socket = io(SOCKET_BASE, {
    auth: { token: sessionId },
    transports: ['websocket'],
    reconnection: true,
    reconnectionAttempts: 8,
    reconnectionDelay: 200,
    reconnectionDelayMax: 750,
    timeout: 5000,
    forceNew: true,
  });
  sockets.push(socket);

  const ready = waitEvent(
    socket,
    'server:ready',
    (data) => String(data?.userId) === String(user.id),
    8000,
  );
  const authError = new Promise((_, reject) => {
    socket.once('auth:error', (data) => {
      reject(new Error(`Socket auth failed for ${user.phone_e164}: ${data?.message ?? 'unknown'}`));
    });
  });

  await Promise.race([ready, authError]);
  user.socket = socket;
  return user;
}

async function main() {
  const usersResult = await pool.query(
    `select id::text, phone_e164
     from users
     where phone_e164 = any($1::text[])
     order by phone_e164 asc`,
    [TEST_PHONES],
  );

  if (usersResult.rows.length !== 2) {
    throw new Error(`Expected 2 CI users from e2e:live, found ${usersResult.rows.length}.`);
  }

  const [userA, userB] = usersResult.rows;
  const matchResult = await pool.query(
    `select id::text as match_id
     from matches
     where unmatched_at is null
       and ((user_a_id=$1 and user_b_id=$2) or (user_a_id=$2 and user_b_id=$1))
     order by id desc
     limit 1`,
    [userA.id, userB.id],
  );
  const matchId = matchResult.rows[0]?.match_id;
  if (!matchId) throw new Error('CI reciprocal users do not have an active match.');

  await Promise.all([connectUser(userA), connectUser(userB)]);
  await emitAck(userA.socket, 'match:join', { matchId });
  await emitAck(userB.socket, 'match:join', { matchId });

  const typingSeen = waitEvent(
    userB.socket,
    'match:typing',
    (event) => String(event?.matchId) === matchId
      && String(event?.userId) === String(userA.id)
      && event?.typing === true,
  );
  await emitAck(userA.socket, 'match:typing', { matchId, typing: true });
  await typingSeen;
  await emitAck(userA.socket, 'match:typing', { matchId, typing: false });

  // e2e:live sends a private message immediately before this smoke test.
  // Respect the production one-message-per-second Redis guard instead of weakening it for CI.
  await waitForPrivateMessageCooldown(userA.id, matchId);

  const messageBody = `ci-socket-${Date.now()}`;
  const messageSeen = waitEvent(
    userB.socket,
    'match:message',
    (event) => String(event?.matchId) === matchId
      && String(event?.message?.body) === messageBody,
  );
  await emitAck(userA.socket, 'match:send', { matchId, body: messageBody });
  await messageSeen;

  const readSeen = waitEvent(
    userA.socket,
    'match:read',
    (event) => String(event?.matchId) === matchId
      && String(event?.readerUserId) === String(userB.id),
  );
  await emitAck(userB.socket, 'match:read', { matchId });
  await readSeen;

  const disconnected = waitEvent(userB.socket, 'disconnect', () => true, 6000);
  const reconnected = waitEvent(userB.socket, 'connect', () => true, 12000);
  userB.socket.io.engine.close();
  await disconnected;
  await reconnected;
  await emitAck(userB.socket, 'match:join', { matchId });

  await waitForPrivateMessageCooldown(userB.id, matchId);
  const afterReconnectBody = `ci-reconnect-${Date.now()}`;
  const afterReconnectSeen = waitEvent(
    userA.socket,
    'match:message',
    (event) => String(event?.matchId) === matchId
      && String(event?.message?.body) === afterReconnectBody,
  );
  await emitAck(userB.socket, 'match:send', { matchId, body: afterReconnectBody });
  await afterReconnectSeen;

  const dbResult = await pool.query(
    `select count(*)::int as count
     from private_messages
     where match_id=$1 and body = any($2::text[])`,
    [matchId, [messageBody, afterReconnectBody]],
  );
  if (dbResult.rows[0]?.count !== 2) {
    throw new Error(`Expected 2 persisted WebSocket messages, found ${dbResult.rows[0]?.count ?? 0}.`);
  }

  console.log('✅ MEET6 SOCKET E2E PASS');
  console.log(`matchId=${matchId}`);
  console.log('Flow: socket auth → match join → typing → private message → read receipt → reconnect → private message');
}

try {
  await main();
} catch (error) {
  console.error('❌ MEET6 SOCKET E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  for (const socket of sockets) {
    try { socket.disconnect(); } catch (_) {}
  }
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
