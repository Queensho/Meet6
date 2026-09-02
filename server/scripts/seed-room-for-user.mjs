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
const TARGET_PHONE = (process.env.TARGET_PHONE ?? '').trim();
const PHOTO = process.env.E2E_PHOTO_PATH
  ?? path.resolve(repoDir, 'assets/images/file_000000009c248210b0e425b8f2d3e68d.png');

if (!TARGET_PHONE) throw new Error('TARGET_PHONE is required, e.g. TARGET_PHONE=+905074035859');
if (process.env.OTP_TEST_MODE !== 'true' || !OTP?.match(/^\d{6}$/)) {
  throw new Error('OTP_TEST_MODE=true and OTP_TEST_CODE are required.');
}
if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required.');
if (!process.env.REDIS_URL) throw new Error('REDIS_URL is required.');
if (!fs.existsSync(PHOTO)) throw new Error(`Test photo not found: ${PHOTO}`);

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: 2 });
const photoBuffer = fs.readFileSync(PHOTO);

const helpers = [
  { phone: '+905550070001', name: 'Test Ece' },
  { phone: '+905550070002', name: 'Test Selin' },
  { phone: '+905550070003', name: 'Test Aslı' },
  { phone: '+905550070004', name: 'Test Deniz' },
  { phone: '+905550070005', name: 'Test Mert' },
];

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

function acceptedHelperGender(lookingFor, index) {
  if (lookingFor === 'Kadınlar') return 'Kadın';
  if (lookingFor === 'Erkekler') return 'Erkek';
  return index % 2 === 0 ? 'Kadın' : 'Erkek';
}

function helperLookingFor(targetGender) {
  if (targetGender === 'Kadın') return 'Kadınlar';
  if (targetGender === 'Erkek') return 'Erkekler';
  return 'Herkes';
}

async function clearHelperUsers() {
  const phones = helpers.map((u) => u.phone);
  const existing = await pool.query(
    'select id::text from users where phone_e164 = any($1::text[])',
    [phones],
  );
  for (const row of existing.rows) {
    const key = `user-sessions:${row.id}`;
    const sessions = await redis.smembers(key);
    if (sessions.length) await redis.del(...sessions.map((id) => `session:${id}`));
    await redis.del(key);
  }
  await pool.query('delete from otp_challenges where phone_e164 = any($1::text[])', [phones]);
  await pool.query('delete from users where phone_e164 = any($1::text[])', [phones]);
  for (const phone of phones) await redis.del(`otp:cooldown:${phone}`);
}

async function createHelper(helper, index, target) {
  await jsonRequest('POST', '/auth/request-code', { body: { phone: helper.phone } });
  const verified = await jsonRequest('POST', '/auth/verify-code', {
    body: { phone: helper.phone, code: OTP },
  });
  helper.sessionId = verified.sessionId;
  helper.userId = String(verified.userId);

  const form = new FormData();
  for (let i = 0; i < 3; i++) {
    form.append('photos', new Blob([photoBuffer], { type: 'image/png' }), `seed-${index + 1}-${i + 1}.png`);
  }
  const uploadResponse = await fetch(`${API}/me/photos`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${helper.sessionId}` },
    body: form,
  });
  const upload = await uploadResponse.json();
  if (!uploadResponse.ok) throw new Error(`Photo upload failed for ${helper.name}: ${upload.message ?? JSON.stringify(upload)}`);

  const gender = acceptedHelperGender(target.looking_for, index);
  const year = Math.max(1965, Math.min(2005, new Date().getUTCFullYear() - Math.max(22, target.min_age + 2)));
  const birthDate = `${year}-0${(index % 8) + 1}-1${index}`;

  await jsonRequest('PUT', '/me/profile', {
    sessionId: helper.sessionId,
    body: {
      displayName: helper.name,
      birthDate,
      gender,
      bio: `${helper.name} Meet6 oda testi için oluşturulmuş test hesabı.`,
      city: target.city || '',
      country: target.country || '',
      latitude: Number(target.latitude),
      longitude: Number(target.longitude),
      profilePrompt: 'İyi bir sohbet nasıl başlar?',
      profileAnswer: 'Doğal bir merhaba ve biraz merakla.',
      interests: ['Kahve', 'Müzik', 'Seyahat'],
      photoUrls: upload.urls,
      profileCompleted: true,
    },
  });

  await jsonRequest('PUT', '/me/preferences', {
    sessionId: helper.sessionId,
    body: {
      lookingFor: helperLookingFor(target.gender),
      minAge: 18,
      maxAge: 65,
      distanceKm: 500,
      purpose: target.purpose || 'Yeni insanlarla tanışma',
    },
  });
  return helper;
}

async function main() {
  const targetResult = await pool.query(
    `select u.id::text as user_id, u.phone_e164,
            p.display_name, p.gender, p.city, p.country, p.latitude, p.longitude,
            mp.looking_for, mp.min_age, mp.max_age, mp.distance_km, mp.purpose
     from users u
     join profiles p on p.user_id = u.id and p.profile_completed = true
     join matching_preferences mp on mp.user_id = u.id
     where u.phone_e164 = $1`,
    [TARGET_PHONE],
  );
  const target = targetResult.rows[0];
  if (!target) throw new Error(`Completed target profile not found for ${TARGET_PHONE}`);
  if (target.latitude == null || target.longitude == null) throw new Error('Target profile has no coordinates.');

  const queued = await pool.query('select 1 from matchmaking_queue where user_id=$1', [target.user_id]);
  if (!queued.rowCount) {
    throw new Error('Target user is not in matchmaking_queue. Open Meet6 and start room search first.');
  }

  await clearHelperUsers();
  console.log(`Target: ${target.display_name} (${TARGET_PHONE})`);

  for (let i = 0; i < helpers.length; i++) {
    await createHelper(helpers[i], i, target);
    console.log(`created ${helpers[i].name} userId=${helpers[i].userId}`);
  }

  for (const helper of helpers) {
    await jsonRequest('POST', '/rooms/queue', { sessionId: helper.sessionId });
  }

  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    const room = await pool.query(
      `select r.id::text
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id=$1 and rm.left_at is null and r.status='active'
       order by r.id desc limit 1`,
      [target.user_id],
    );
    if (room.rows[0]?.id) {
      const count = await pool.query('select count(*)::int as count from room_members where room_id=$1', [room.rows[0].id]);
      console.log(`\n✅ TEST ROOM READY roomId=${room.rows[0].id} members=${count.rows[0].count}`);
      console.log('Return to the Meet6 browser tab; it should open the room automatically within the next poll.');
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  throw new Error('Five helper accounts were queued but the target did not enter a room. Check target age/gender preferences.');
}

try {
  await main();
} catch (error) {
  console.error('\n❌ SEED ROOM FAILED');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
