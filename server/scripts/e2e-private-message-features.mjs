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
      reject(new Error(`Timed out waiting for ${event}`));
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
        reject(new Error(`${event}: ${response.error ?? 'operation failed'}`));
        return;
      }
      resolve(response ?? {});
    });
  });
}

async function activeSession(userId) {
  const ids = await redis.smembers(`user-sessions:${userId}`);
  for (const id of ids) {
    const owner = await redis.get(`session:${id}`);
    if (String(owner) === String(userId)) return id;
  }
  throw new Error(`No active session for user ${userId}.`);
}

async function connectUser(user) {
  const token = await activeSession(user.id);
  const socket = io(SOCKET_BASE, {
    auth: { token },
    transports: ['websocket'],
    reconnection: false,
    timeout: 5000,
    forceNew: true,
  });
  sockets.push(socket);
  await waitEvent(
    socket,
    'server:ready',
    (data) => String(data?.userId) === String(user.id),
  );
  user.socket = socket;
  return user;
}

async function waitForMessageCooldown(userId, matchId) {
  const key = `private-message:${userId}:${matchId}`;
  const remaining = await redis.pttl(key);
  if (remaining > 0) await sleep(remaining + 180);
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
    throw new Error(`Expected 2 test users, found ${usersResult.rows.length}.`);
  }
  const [userA, userB] = usersResult.rows;

  const matchResult = await pool.query(
    `select id::text as match_id
     from matches
     where unmatched_at is null
       and ((user_a_id=$1 and user_b_id=$2) or (user_a_id=$2 and user_b_id=$1))
     order by id desc limit 1`,
    [userA.id, userB.id],
  );
  const matchId = matchResult.rows[0]?.match_id;
  if (!matchId) throw new Error('Active test match was not found.');

  await Promise.all([connectUser(userA), connectUser(userB)]);

  const detailA = await emitAck(userA.socket, 'match:join', { matchId });
  await emitAck(userB.socket, 'match:join', { matchId });
  if (detailA?.profile?.online !== true) {
    throw new Error('Exact online presence was not returned from match:join.');
  }

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

  await waitForMessageCooldown(userA.id, matchId);
  const body = `ci-private-features-${Date.now()}`;
  const messageSeen = waitEvent(
    userB.socket,
    'match:message',
    (event) => String(event?.matchId) === matchId
      && String(event?.message?.body) === body,
  );
  const sent = await emitAck(userA.socket, 'match:send', { matchId, body });
  const seen = await messageSeen;
  const messageId = String(sent?.message?.id ?? seen?.message?.id ?? '');
  if (!messageId) throw new Error('Sent message id is missing.');

  const deliveredSeen = waitEvent(
    userA.socket,
    'match:delivered',
    (event) => String(event?.matchId) === matchId
      && String(event?.messageId) === messageId
      && String(event?.recipientUserId) === String(userB.id),
  );
  await emitAck(userB.socket, 'match:delivered', { matchId, messageId });
  await deliveredSeen;

  const deliveredDb = await pool.query(
    'select delivered_at from private_messages where id=$1 and match_id=$2',
    [messageId, matchId],
  );
  if (!deliveredDb.rows[0]?.delivered_at) {
    throw new Error('delivered_at was not persisted.');
  }

  const readSeen = waitEvent(
    userA.socket,
    'match:read',
    (event) => String(event?.matchId) === matchId
      && String(event?.readerUserId) === String(userB.id),
  );
  await emitAck(userB.socket, 'match:read', { matchId });
  await readSeen;

  const readDb = await pool.query(
    'select delivered_at, read_at from private_messages where id=$1 and match_id=$2',
    [messageId, matchId],
  );
  if (!readDb.rows[0]?.delivered_at || !readDb.rows[0]?.read_at) {
    throw new Error('Read receipt did not persist delivered_at + read_at.');
  }

  const deletedSeen = waitEvent(
    userB.socket,
    'match:message-deleted',
    (event) => String(event?.matchId) === matchId
      && String(event?.messageId) === messageId
      && String(event?.deletedByUserId) === String(userA.id),
  );
  await emitAck(userA.socket, 'match:delete', { matchId, messageId });
  await deletedSeen;

  const deletedDb = await pool.query(
    'select count(*)::int as count from private_messages where id=$1',
    [messageId],
  );
  if (deletedDb.rows[0]?.count !== 0) {
    throw new Error('Deleted message still exists in the database.');
  }

  const offlineSeen = waitEvent(
    userA.socket,
    'presence:update',
    (event) => String(event?.userId) === String(userB.id) && event?.online === false,
    10000,
  );
  userB.socket.disconnect();
  await offlineSeen;
  await sleep(150);

  const offlineDetail = await emitAck(userA.socket, 'match:join', { matchId });
  if (offlineDetail?.profile?.online !== false) {
    throw new Error('Peer remained online after disconnect.');
  }
  if (!offlineDetail?.profile?.last_seen_at) {
    throw new Error('Visible peer last_seen_at is missing after disconnect.');
  }

  console.log('✅ MEET6 PRIVATE MESSAGE FEATURES E2E PASS');
  console.log(`matchId=${matchId}`);
  console.log(`messageId=${messageId}`);
  console.log('Flow: exact presence → typing → send → delivered → read → delete → last seen');
}

try {
  await main();
} catch (error) {
  console.error('❌ MEET6 PRIVATE MESSAGE FEATURES E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  for (const socket of sockets) {
    try { socket.disconnect(); } catch (_) {}
  }
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
