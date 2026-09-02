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

const API = process.env.E2E_API_BASE ?? 'http://127.0.0.1:3100/api';
const SOCKET_BASE = process.env.E2E_SOCKET_BASE ?? 'http://127.0.0.1:3100/rooms';
const TARGET_PHONE = (process.env.TARGET_PHONE ?? '+905074035859').trim();

if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required.');
if (!process.env.REDIS_URL) throw new Error('REDIS_URL is required.');

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: 2 });
const sockets = [];

const allowedHelperPhones = new Set([
  '+905550070001',
  '+905550070002',
  '+905550070003',
  '+905550070004',
  '+905550070005',
]);

function log(label, value = '') {
  console.log(`\n=== ${label} ===`);
  if (value !== '') console.log(value);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function jsonRequest(method, urlPath, { sessionId, body } = {}) {
  const headers = { Accept: 'application/json' };
  if (sessionId) headers.Authorization = `Bearer ${sessionId}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const response = await fetch(`${API}${urlPath}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data = {};
  if (text) {
    try { data = JSON.parse(text); } catch { data = { raw: text }; }
  }
  if (!response.ok) {
    const message = Array.isArray(data.message)
      ? data.message.join('; ')
      : data.message ?? data.raw ?? response.statusText;
    throw new Error(`${method} ${urlPath} -> HTTP ${response.status}: ${message}`);
  }
  return data;
}

async function activeSession(userId) {
  const ids = await redis.smembers(`user-sessions:${userId}`);
  for (const id of ids) {
    const owner = await redis.get(`session:${id}`);
    if (String(owner) === String(userId)) return id;
  }
  throw new Error(`No active Redis session for userId=${userId}. Open/login to Meet6 and seed the test room again.`);
}

function waitEvent(socket, event, predicate = () => true, timeoutMs = 6000) {
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

function emitAck(socket, event, payload = {}, timeoutMs = 6000) {
  return new Promise((resolve, reject) => {
    socket.timeout(timeoutMs).emit(event, payload, (error, response) => {
      if (error) return reject(new Error(`${event} ack timeout/error: ${error.message ?? error}`));
      if (response?.ok === false) return reject(new Error(`${event}: ${response.error ?? 'socket operation failed'}`));
      resolve(response ?? {});
    });
  });
}

async function connectMember(member) {
  const sessionId = await activeSession(member.user_id);
  const socket = io(SOCKET_BASE, {
    auth: { token: sessionId },
    transports: ['websocket'],
    reconnection: true,
    reconnectionAttempts: 8,
    reconnectionDelay: 250,
    reconnectionDelayMax: 1000,
    timeout: 5000,
    forceNew: true,
  });
  sockets.push(socket);

  const ready = waitEvent(socket, 'server:ready', (data) => String(data?.userId) === String(member.user_id), 7000);
  const authError = new Promise((_, reject) => {
    socket.once('auth:error', (data) => reject(new Error(`Socket auth failed for ${member.display_name}: ${data?.message ?? 'unknown'}`)));
  });
  await Promise.race([ready, authError]);
  member.sessionId = sessionId;
  member.socket = socket;
  return member;
}

async function currentTestRoom() {
  const targetResult = await pool.query(
    `select u.id::text as user_id, u.phone_e164, p.display_name
     from users u
     join profiles p on p.user_id=u.id
     where u.phone_e164=$1 and p.profile_completed=true`,
    [TARGET_PHONE],
  );
  const target = targetResult.rows[0];
  if (!target) throw new Error(`Completed target account not found: ${TARGET_PHONE}`);

  const roomResult = await pool.query(
    `select r.id::text as room_id
     from room_members rm
     join rooms r on r.id=rm.room_id
     where rm.user_id=$1 and rm.left_at is null and r.status='active'
     order by r.id desc limit 1`,
    [target.user_id],
  );
  const roomId = roomResult.rows[0]?.room_id;
  if (!roomId) {
    throw new Error('Target is not in an active room. Run TARGET_PHONE="+905074035859" node scripts/seed-room-for-user.mjs first.');
  }

  const memberResult = await pool.query(
    `select u.id::text as user_id, u.phone_e164, p.display_name
     from room_members rm
     join users u on u.id=rm.user_id
     join profiles p on p.user_id=u.id
     where rm.room_id=$1 and rm.left_at is null
     order by rm.joined_at asc`,
    [roomId],
  );
  if (memberResult.rows.length !== 6) throw new Error(`Room ${roomId} has ${memberResult.rows.length} members, expected 6.`);

  const others = memberResult.rows.filter((row) => row.phone_e164 !== TARGET_PHONE);
  const unsafe = others.filter((row) => !allowedHelperPhones.has(row.phone_e164));
  if (unsafe.length) {
    throw new Error(`Refusing realtime test: room ${roomId} contains non-test users: ${unsafe.map((u) => u.phone_e164).join(', ')}`);
  }
  if (others.length !== 5) throw new Error('Expected exactly five known helper accounts in the target room.');

  const ordered = [
    memberResult.rows.find((row) => row.phone_e164 === TARGET_PHONE),
    ...others,
  ];
  return { roomId, members: ordered };
}

async function main() {
  log('REALTIME E2E START', `API=${API}\nSOCKET=${SOCKET_BASE}\nTARGET=${TARGET_PHONE}`);

  const { roomId, members } = await currentTestRoom();
  log('SAFE TEST ROOM', `roomId=${roomId}\n${members.map((m) => `${m.display_name} ${m.phone_e164}`).join('\n')}`);

  await Promise.all(members.map(connectMember));
  for (const member of members) {
    await emitAck(member.socket, 'room:join', { roomId });
  }
  log('SOCKET CONNECT', '6/6 authenticated Socket.IO clients joined the room channel.');

  const [target, helperA, helperB, helperC, helperD] = members;

  const roomText = `realtime-room-${Date.now()}`;
  const roomMessageSeen = waitEvent(
    helperA.socket,
    'room:message',
    (event) => String(event?.roomId) === roomId && String(event?.message?.body) === roomText,
  );
  await emitAck(target.socket, 'room:send', { roomId, body: roomText });
  await roomMessageSeen;
  log('ROOM MESSAGE', 'Target message reached another account instantly through WebSocket.');

  const reconnectOffline = waitEvent(
    target.socket,
    'presence:update',
    (event) => String(event?.userId) === String(helperB.user_id) && event?.online === false,
    8000,
  );
  const reconnectOnline = waitEvent(
    target.socket,
    'presence:update',
    (event) => String(event?.userId) === String(helperB.user_id) && event?.online === true,
    12000,
  );
  const disconnected = waitEvent(helperB.socket, 'disconnect', () => true, 6000);
  const reconnected = waitEvent(helperB.socket, 'connect', () => true, 12000);
  helperB.socket.io.engine.close();
  await disconnected;
  await reconnectOffline;
  await reconnected;
  await reconnectOnline;
  await emitAck(helperB.socket, 'room:join', { roomId });

  const reconnectText = `after-reconnect-${Date.now()}`;
  const postReconnectSeen = waitEvent(
    target.socket,
    'room:message',
    (event) => String(event?.roomId) === roomId && String(event?.message?.body) === reconnectText,
  );
  await emitAck(helperB.socket, 'room:send', { roomId, body: reconnectText });
  await postReconnectSeen;
  log('RECONNECT + PRESENCE', 'Transport drop triggered automatic reconnect, offline/online presence, and messaging continued.');

  await pool.query('delete from room_extension_votes where room_id=$1', [roomId]);
  await pool.query(
    `update rooms set ends_at=now()+interval '60 seconds', extended=false where id=$1 and status='active'`,
    [roomId],
  );
  const extendedEvent = waitEvent(
    target.socket,
    'room:update',
    (event) => String(event?.roomId) === roomId && event?.room?.extended === true,
    7000,
  );
  let extensionAck;
  for (const voter of [target, helperA, helperB, helperC]) {
    extensionAck = await emitAck(voter.socket, 'room:extension', { roomId, vote: true });
  }
  await extendedEvent;
  if (extensionAck?.extended !== true) throw new Error('Four yes votes did not extend the room.');
  log('EXTENSION', '4 realtime yes votes extended the room by +5 minutes.');

  const capability = await jsonRequest('GET', `/rooms/${roomId}/force-selection-capability`, {
    sessionId: target.sessionId,
  });
  if (capability.allowed !== true) {
    throw new Error(`Target force-selection capability is not enabled. Check ROOM_FORCE_END_PHONE. response=${JSON.stringify(capability)}`);
  }

  const selectionPush = waitEvent(
    helperA.socket,
    'room:update',
    (event) => String(event?.roomId) === roomId && event?.room?.status === 'selection',
    6000,
  );
  const forceResult = await jsonRequest('PUT', `/rooms/${roomId}/force-selection`, {
    sessionId: target.sessionId,
  });
  await selectionPush;
  if (forceResult.status !== 'selection' || Number(forceResult.selectionSecondsLeft) !== 10) {
    throw new Error(`Force selection returned unexpected state: ${JSON.stringify(forceResult)}`);
  }
  log('FORCE END', 'Tayfun permission ended the room and all clients received 10-second selection state instantly.');

  const targetMatchPush = waitEvent(
    target.socket,
    'match:created',
    (event) => String(event?.roomId) === roomId,
    6000,
  );
  const helperMatchPush = waitEvent(
    helperA.socket,
    'match:created',
    (event) => String(event?.roomId) === roomId,
    6000,
  );

  await emitAck(target.socket, 'room:selection', {
    roomId,
    selectedUserId: Number(helperA.user_id),
  });
  const matchAck = await emitAck(helperA.socket, 'room:selection', {
    roomId,
    selectedUserId: Number(target.user_id),
  });
  const [targetMatch, helperMatch] = await Promise.all([targetMatchPush, helperMatchPush]);
  const matchId = String(matchAck.matchId ?? targetMatch.matchId ?? helperMatch.matchId ?? '');
  if (!matchId) throw new Error('Realtime reciprocal selection did not create a matchId.');
  log('SECRET SELECTION', `Mutual selection created matchId=${matchId} and pushed it to both users.`);

  await emitAck(target.socket, 'match:join', { matchId });
  await emitAck(helperA.socket, 'match:join', { matchId });

  const typingSeen = waitEvent(
    helperA.socket,
    'match:typing',
    (event) => String(event?.matchId) === matchId && String(event?.userId) === String(target.user_id) && event?.typing === true,
  );
  await emitAck(target.socket, 'match:typing', { matchId, typing: true });
  await typingSeen;
  await emitAck(target.socket, 'match:typing', { matchId, typing: false });
  log('TYPING', 'Typing indicator arrived instantly on the matched account.');

  const privateText = `realtime-private-${Date.now()}`;
  const privateSeen = waitEvent(
    helperA.socket,
    'match:message',
    (event) => String(event?.matchId) === matchId && String(event?.message?.body) === privateText,
  );
  await emitAck(target.socket, 'match:send', { matchId, body: privateText });
  await privateSeen;
  log('PRIVATE MESSAGE', 'Private message reached the other matched client through WebSocket.');

  const readSeen = waitEvent(
    target.socket,
    'match:read',
    (event) => String(event?.matchId) === matchId && String(event?.readerUserId) === String(helperA.user_id),
  );
  await emitAck(helperA.socket, 'match:read', { matchId });
  await readSeen;
  log('READ RECEIPT', 'Read receipt returned to the sender instantly.');

  const db = await pool.query(
    `select
       (select count(*) from room_members where room_id=$1)::int as members,
       (select count(*) from room_messages where room_id=$1)::int as room_messages,
       (select count(*) from room_extension_votes where room_id=$1 and vote=true)::int as yes_votes,
       (select count(*) from room_selections where room_id=$1)::int as selections,
       (select count(*) from matches where id=$2 and unmatched_at is null)::int as matches,
       (select count(*) from private_messages where match_id=$2)::int as private_messages`,
    [roomId, matchId],
  );
  log('DATABASE CHECK', JSON.stringify(db.rows[0], null, 2));

  console.log('\n✅ MEET6 REALTIME E2E PASS');
  console.log(`roomId=${roomId}`);
  console.log(`matchId=${matchId}`);
  console.log('Flow: socket auth → room join → live message → reconnect/presence → +5 vote → privileged force-end → 10s selection → match → typing → private message → read receipt');
}

try {
  await main();
} catch (error) {
  console.error('\n❌ MEET6 REALTIME E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  for (const socket of sockets) {
    try { socket.disconnect(); } catch (_) {}
  }
  await sleep(100);
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
