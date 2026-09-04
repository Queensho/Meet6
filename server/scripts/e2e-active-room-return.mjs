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
  throw new Error(`No active session for E2E user ${userId}.`);
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
  if (!response.ok) {
    throw new Error(`${method} ${pathName} -> ${response.status}: ${data.message ?? data.raw ?? response.statusText}`);
  }
  return data;
}

async function main() {
  const result = await pool.query(
    `select id::text,phone_e164 from users
     where phone_e164=any($1::text[]) order by phone_e164 asc`,
    [TEST_PHONES],
  );
  if (result.rows.length !== 6) throw new Error(`Expected 6 E2E users, found ${result.rows.length}.`);
  const ids = result.rows.map((row) => row.id);
  const owner = result.rows[0];
  const sessionId = await activeSession(owner.id);

  // Remove any open room state left by earlier CI scenarios for these test accounts.
  await pool.query(
    `update rooms set status='closed',closed_at=coalesce(closed_at,now())
     where id in (
       select distinct room_id from room_members
       where user_id=any($1::bigint[])
     ) and status in ('active','selection')`,
    [ids],
  );
  await pool.query(
    `update room_members set left_at=coalesce(left_at,now())
     where user_id=any($1::bigint[]) and left_at is null`,
    [ids],
  );

  const created = await pool.query(
    `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
     values('active',now()-interval '2 days',now()+interval '10 minutes',15,'text')
     returning id::text`,
  );
  const roomId = created.rows[0].id;
  for (const userId of ids) {
    await pool.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, userId]);
  }

  try {
    const current = await request('GET', '/room-session/current', sessionId);
    if (String(current.room?.id ?? '') !== roomId) {
      throw new Error(`Current room mismatch: ${JSON.stringify(current)}`);
    }
    if (current.room?.roomMode !== 'text') {
      throw new Error(`Expected text roomMode, got ${current.room?.roomMode}`);
    }

    const left = await request('DELETE', `/room-session/${roomId}`, sessionId);
    if (left.left !== true || String(left.roomId) !== roomId) {
      throw new Error(`Leave response mismatch: ${JSON.stringify(left)}`);
    }

    const after = await request('GET', '/room-session/current', sessionId);
    if (after.room != null) {
      throw new Error(`Expected no current room after leave: ${JSON.stringify(after)}`);
    }

    const membership = await pool.query(
      'select left_at from room_members where room_id=$1 and user_id=$2',
      [roomId, owner.id],
    );
    if (!membership.rows[0]?.left_at) throw new Error('Voluntary leave did not persist left_at.');

    console.log('✅ MEET6 ACTIVE ROOM RETURN E2E PASS');
    console.log(`current room ${roomId} -> explicit leave -> current=null`);
  } finally {
    await pool.query("update rooms set status='closed',closed_at=coalesce(closed_at,now()) where id=$1", [roomId]);
    await pool.query('update room_members set left_at=coalesce(left_at,now()) where room_id=$1', [roomId]);
  }
}

try {
  await main();
} catch (error) {
  console.error('❌ MEET6 ACTIVE ROOM RETURN E2E FAIL');
  console.error(error?.stack ?? error);
  process.exitCode = 1;
} finally {
  await pool.end().catch(() => undefined);
  redis.disconnect();
}
