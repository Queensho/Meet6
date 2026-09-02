import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
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
const OTP = process.env.OTP_TEST_CODE?.trim();
const PHOTO = process.env.E2E_PHOTO_PATH
  ?? path.resolve(repoDir, 'assets/images/file_000000009c248210b0e425b8f2d3e68d.png');

if (process.env.OTP_TEST_MODE !== 'true' || !OTP?.match(/^\d{6}$/)) {
  throw new Error('E2E test requires OTP_TEST_MODE=true and a six-digit OTP_TEST_CODE.');
}
if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required.');
if (!process.env.REDIS_URL) throw new Error('REDIS_URL is required.');
if (!fs.existsSync(PHOTO)) throw new Error(`Test photo not found: ${PHOTO}`);

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: 2 });
const photoBuffer = fs.readFileSync(PHOTO);

const users = [
  { phone: '+905550060001', name: 'Test Aslı', gender: 'Kadın', birthDate: '1997-03-12' },
  { phone: '+905550060002', name: 'Test Mert', gender: 'Erkek', birthDate: '1995-08-22' },
  { phone: '+905550060003', name: 'Test Ece', gender: 'Kadın', birthDate: '1998-05-06' },
  { phone: '+905550060004', name: 'Test Bora', gender: 'Erkek', birthDate: '1996-11-18' },
  { phone: '+905550060005', name: 'Test Selin', gender: 'Kadın', birthDate: '1999-01-27' },
  { phone: '+905550060006', name: 'Test Deniz', gender: 'Erkek', birthDate: '1994-09-09' },
];

function log(label, value = '') {
  console.log(`\n=== ${label} ===`);
  if (value !== '') console.log(value);
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
    const message = Array.isArray(data.message) ? data.message.join('; ') : data.message ?? data.raw ?? response.statusText;
    throw new Error(`${method} ${urlPath} -> HTTP ${response.status}: ${message}`);
  }
  return data;
}

async function cleanOldTestUsers() {
  const phones = users.map((u) => u.phone);
  const result = await pool.query(
    'select id::text, phone_e164 from users where phone_e164 = any($1::text[])',
    [phones],
  );
  for (const row of result.rows) {
    const key = `user-sessions:${row.id}`;
    const sessions = await redis.smembers(key);
    if (sessions.length) await redis.del(...sessions.map((id) => `session:${id}`));
    await redis.del(key);
  }
  await pool.query('delete from otp_challenges where phone_e164 = any($1::text[])', [phones]);
  await pool.query('delete from users where phone_e164 = any($1::text[])', [phones]);
  for (const phone of phones) await redis.del(`otp:cooldown:${phone}`);
}

async function createUser(user, index) {
  await jsonRequest('POST', '/auth/request-code', { body: { phone: user.phone } });
  const verified = await jsonRequest('POST', '/auth/verify-code', {
    body: { phone: user.phone, code: OTP },
  });
  user.sessionId = verified.sessionId;
  user.userId = String(verified.userId);

  const form = new FormData();
  for (let i = 0; i < 3; i++) {
    form.append('photos', new Blob([photoBuffer], { type: 'image/png' }), `test-${index + 1}-${i + 1}.png`);
  }
  const uploadResponse = await fetch(`${API}/me/photos`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${user.sessionId}` },
    body: form,
  });
  const upload = await uploadResponse.json();
  if (!uploadResponse.ok) {
    throw new Error(`photo upload ${user.name} -> HTTP ${uploadResponse.status}: ${upload.message ?? JSON.stringify(upload)}`);
  }
  if (!Array.isArray(upload.urls) || upload.urls.length !== 3) {
    throw new Error(`${user.name}: expected 3 uploaded photo URLs.`);
  }
  user.photoUrls = upload.urls;

  await jsonRequest('PUT', '/me/profile', {
    sessionId: user.sessionId,
    body: {
      displayName: user.name,
      birthDate: user.birthDate,
      gender: user.gender,
      bio: `${user.name} için Meet6 canlı uçtan uca test profili.`,
      city: 'İstanbul',
      country: 'Türkiye',
      latitude: 41.015137,
      longitude: 28.979530,
      profilePrompt: 'İyi bir sohbetin sırrı nedir?',
      profileAnswer: 'Doğal olmak, merak etmek ve karşıdakini gerçekten dinlemek.',
      interests: ['Kahve', 'Müzik', 'Seyahat'],
      photoUrls: upload.urls,
      profileCompleted: true,
    },
  });
  await jsonRequest('PUT', '/me/preferences', {
    sessionId: user.sessionId,
    body: {
      lookingFor: 'Herkes',
      minAge: 18,
      maxAge: 65,
      distanceKm: 50,
      purpose: 'Yeni insanlarla tanışma',
    },
  });
  return user;
}

async function waitForRoom(timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const statuses = await Promise.all(users.map((u) =>
      jsonRequest('GET', '/rooms/queue', { sessionId: u.sessionId })
    ));
    const rooms = statuses.filter((s) => s.state === 'room').map((s) => s.room);
    if (rooms.length === users.length) {
      const ids = new Set(rooms.map((room) => String(room.id)));
      if (ids.size !== 1) throw new Error(`Users landed in different rooms: ${[...ids].join(', ')}`);
      return rooms[0];
    }
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  throw new Error('Timed out waiting for all six users to enter one room.');
}

async function main() {
  log('E2E START', `API=${API}`);
  await cleanOldTestUsers();
  log('CLEAN', 'Previous Meet6 E2E users removed.');

  for (let i = 0; i < users.length; i++) {
    await createUser(users[i], i);
    console.log(`created ${users[i].name} userId=${users[i].userId}`);
  }
  log('PROFILES', '6/6 users created through OTP + photo upload + profile APIs.');

  for (const user of users) {
    await jsonRequest('POST', '/rooms/queue', { sessionId: user.sessionId });
  }
  const room = await waitForRoom();
  const roomId = String(room.id);
  if (!Array.isArray(room.members) || room.members.length !== 6) {
    throw new Error(`Room ${roomId} does not contain exactly six members.`);
  }
  log('MATCHMAKING', `6 users entered room ${roomId}.`);

  await jsonRequest('POST', `/rooms/${roomId}/messages`, {
    sessionId: users[0].sessionId,
    body: { body: 'Aslı test mesajı: oda sohbeti çalışıyor 👋' },
  });
  await jsonRequest('POST', `/rooms/${roomId}/messages`, {
    sessionId: users[1].sessionId,
    body: { body: 'Mert test cevabı: mesajı aldım ✅' },
  });
  const roomMessages = await jsonRequest('GET', `/rooms/${roomId}/messages`, {
    sessionId: users[2].sessionId,
  });
  const messageBodies = roomMessages.messages?.map((m) => m.body) ?? [];
  if (!messageBodies.some((body) => String(body).includes('Aslı test mesajı'))
      || !messageBodies.some((body) => String(body).includes('Mert test cevabı'))) {
    throw new Error('Cross-user room messages were not visible.');
  }
  log('ROOM CHAT', 'Messages sent by two accounts are visible to a third account.');

  await pool.query("update rooms set ends_at = now() + interval '60 seconds', extended=false where id=$1", [roomId]);
  let extensionResult;
  for (let i = 0; i < 4; i++) {
    extensionResult = await jsonRequest('PUT', `/rooms/${roomId}/extension-vote`, {
      sessionId: users[i].sessionId,
      body: { vote: true },
    });
  }
  if (!extensionResult?.extended) throw new Error('Room was not extended after four yes votes.');
  log('EXTENSION', '4 yes votes extended the room by +5 minutes.');

  await pool.query("update rooms set ends_at = now() - interval '1 second' where id=$1", [roomId]);
  const selectionRoom = await jsonRequest('GET', `/rooms/${roomId}`, { sessionId: users[0].sessionId });
  if (selectionRoom.status !== 'selection') throw new Error(`Expected selection state, got ${selectionRoom.status}`);
  log('TIMER FAST-FORWARD', 'Room moved to secret selection without waiting 15+5 minutes.');

  const choices = [
    [0, 1],
    [1, 0],
    [2, 3],
    [3, 4],
    [4, 5],
    [5, 2],
  ];
  let matchId = null;
  for (const [from, to] of choices) {
    const result = await jsonRequest('PUT', `/rooms/${roomId}/selection`, {
      sessionId: users[from].sessionId,
      body: { selectedUserId: Number(users[to].userId) },
    });
    if (from === 1 && to === 0) matchId = result.matchId;
  }
  if (!matchId) throw new Error('Reciprocal selection did not create a match.');
  const selectionA = await jsonRequest('GET', `/rooms/${roomId}/selection-result`, { sessionId: users[0].sessionId });
  const selectionB = await jsonRequest('GET', `/rooms/${roomId}/selection-result`, { sessionId: users[1].sessionId });
  if (!selectionA.matched || !selectionB.matched || String(selectionA.matchId) !== String(matchId)) {
    throw new Error('Match result is inconsistent between reciprocal users.');
  }
  log('SECRET SELECTION', `Test Aslı ↔ Test Mert matched. matchId=${matchId}`);

  const matchesA = await jsonRequest('GET', '/matches', { sessionId: users[0].sessionId });
  const matchesB = await jsonRequest('GET', '/matches', { sessionId: users[1].sessionId });
  if (!matchesA.matches?.some((m) => String(m.match_id) === String(matchId))
      || !matchesB.matches?.some((m) => String(m.match_id) === String(matchId))) {
    throw new Error('New match is missing from one of the match lists.');
  }
  log('MATCH LIST', 'Match appears for both users.');

  await jsonRequest('POST', `/matches/${matchId}/messages`, {
    sessionId: users[0].sessionId,
    body: { body: 'Eşleşme sonrası gerçek özel mesaj testi ✅' },
  });
  const privateInbox = await jsonRequest('GET', `/matches/${matchId}/messages`, {
    sessionId: users[1].sessionId,
  });
  if (!privateInbox.messages?.some((m) => String(m.body).includes('gerçek özel mesaj testi'))) {
    throw new Error('Private message did not reach the matched user.');
  }
  await jsonRequest('POST', `/matches/${matchId}/read`, { sessionId: users[1].sessionId });
  log('PRIVATE CHAT', 'Private message reached the other account and was marked read.');

  const dbChecks = await pool.query(
    `select
       (select count(*) from room_members where room_id=$1)::int as members,
       (select count(*) from room_messages where room_id=$1)::int as room_messages,
       (select count(*) from room_selections where room_id=$1)::int as selections,
       (select count(*) from matches where id=$2 and unmatched_at is null)::int as matches,
       (select count(*) from private_messages where match_id=$2)::int as private_messages`,
    [roomId, matchId],
  );
  log('DATABASE CHECK', JSON.stringify(dbChecks.rows[0], null, 2));

  console.log('\n✅ MEET6 E2E PASS');
  console.log(`roomId=${roomId}`);
  console.log(`matchId=${matchId}`);
  console.log('Flow: OTP(test) → photos/profile → 6-person matchmaking → room chat → +5 vote → selection → match → private chat');
}

try {
  await main();
} catch (error) {
  console.error('\n❌ MEET6 E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
