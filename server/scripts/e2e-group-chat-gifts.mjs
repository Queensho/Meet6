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
  const sessionId = `gift-e2e-${randomUUID()}`;
  await redis.multi()
    .set(`session:${sessionId}`, String(userId), 'EX', 3600)
    .sadd(`user-sessions:${userId}`, sessionId)
    .expire(`user-sessions:${userId}`, 3600)
    .exec();
  return sessionId;
}

async function rawRequest(method, pathName, sessionId, body) {
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
  return { status: response.status, ok: response.ok, data };
}

async function request(method, pathName, sessionId, body) {
  const result = await rawRequest(method, pathName, sessionId, body);
  if (!result.ok) {
    throw new Error(`${method} ${pathName} -> ${result.status}: ${result.data.message ?? result.data.raw ?? 'error'}`);
  }
  return result.data;
}

async function closeActiveRooms(ids) {
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

async function main() {
  const base = await pool.query(
    `select id::text,phone_e164 from users
     where phone_e164=any($1::text[]) order by phone_e164 asc`,
    [TEST_PHONES],
  );
  if (base.rows.length !== 6) throw new Error(`Expected 6 E2E users, found ${base.rows.length}.`);

  const users = [];
  for (const row of base.rows) users.push({ ...row, sessionId: await activeSession(row.id) });
  const ids = users.map((user) => user.id);
  await closeActiveRooms(ids);

  await pool.query(
    `insert into user_wallets(user_id)
     select unnest($1::bigint[])
     on conflict(user_id) do nothing`,
    [ids],
  );

  const beforeWallets = await pool.query(
    `select user_id::text,coin_balance,gift_xp,generosity_xp,profile_xp,gifts_received,gifts_sent
     from user_wallets where user_id=any($1::bigint[])`,
    [ids],
  );
  const walletSnapshot = new Map(beforeWallets.rows.map((row) => [row.user_id, row]));

  const matchesBefore = await pool.query('select count(*)::int as count from matches');

  const roomResult = await pool.query(
    `insert into rooms(status,started_at,ends_at,room_duration_minutes,room_mode)
     values('active',now(),now()+interval '15 minutes',15,'text')
     returning id::text`,
  );
  const roomId = roomResult.rows[0].id;
  for (const userId of ids) {
    await pool.query('insert into room_members(room_id,user_id) values($1,$2)', [roomId, userId]);
  }

  const sender = users[0];
  const recipient = users[1];
  await pool.query('delete from user_daily_gift_usage where user_id=any($1::bigint[])', [[sender.id, recipient.id]]);
  await pool.query(
    `update user_wallets
     set coin_balance=500,gift_xp=0,generosity_xp=0,profile_xp=0,gifts_received=0,gifts_sent=0,updated_at=now()
     where user_id=any($1::bigint[])`,
    [[sender.id, recipient.id]],
  );

  const catalog = await request('GET', '/gifts/catalog', sender.sessionId);
  if (!Array.isArray(catalog.gifts) || catalog.gifts.length !== 9) {
    throw new Error(`Expected 9 active gifts including the free gift, got ${catalog.gifts?.length}.`);
  }
  const freeGift = catalog.gifts.find((gift) => gift.code === 'free_wave');
  if (!freeGift || Number(freeGift.coinCost) !== 0 || Number(freeGift.profileXp) !== 1 || freeGift.dailyFree !== true) {
    throw new Error(`Free gift catalog entry mismatch: ${JSON.stringify(freeGift)}`);
  }
  if (Number(catalog.freeGiftAllowance?.remaining) !== 3) {
    throw new Error(`Expected 3 daily free gifts: ${JSON.stringify(catalog.freeGiftAllowance)}`);
  }
  if (Number(catalog.wallet?.coinBalance) !== 500) {
    throw new Error(`Catalog wallet balance mismatch: ${JSON.stringify(catalog.wallet)}`);
  }
  if (catalog.rules?.affectsMatching !== false) {
    throw new Error('Gift rules must explicitly keep matchmaking unaffected.');
  }

  const clientGiftId = `gift-e2e-${randomUUID()}`;
  const sent = await request('POST', `/gifts/rooms/${roomId}/send`, sender.sessionId, {
    recipientUserId: Number(recipient.id),
    giftCode: 'rose',
    clientGiftId,
  });
  if (sent.deduplicated !== false || sent.gift?.gift_code !== 'rose') {
    throw new Error(`First gift send failed: ${JSON.stringify(sent)}`);
  }
  if (Number(sent.wallet?.coinBalance) !== 495 || Number(sent.wallet?.generosityXp) !== 5) {
    throw new Error(`Sender wallet/XP did not update atomically: ${JSON.stringify(sent.wallet)}`);
  }
  if (Number(sent.wallet?.profileXp) !== 2) {
    throw new Error(`Sender profile XP should gain 2 from rose: ${JSON.stringify(sent.wallet)}`);
  }
  if (Number(sent.recipientSummary?.giftXp) !== 5 || Number(sent.recipientSummary?.giftsReceived) !== 1) {
    throw new Error(`Recipient gift XP did not update: ${JSON.stringify(sent.recipientSummary)}`);
  }
  if (Number(sent.recipientSummary?.profileXp) !== 2) {
    throw new Error(`Recipient profile XP should gain 2 from rose: ${JSON.stringify(sent.recipientSummary)}`);
  }

  const replay = await request('POST', `/gifts/rooms/${roomId}/send`, sender.sessionId, {
    recipientUserId: Number(recipient.id),
    giftCode: 'rose',
    clientGiftId,
  });
  if (replay.deduplicated !== true || Number(replay.wallet?.coinBalance) !== 495) {
    throw new Error(`Gift idempotency failed: ${JSON.stringify(replay)}`);
  }
  if (Number(replay.wallet?.profileXp) !== 2) {
    throw new Error('Idempotent replay must not grant profile XP twice.');
  }

  const history = await request('GET', `/gifts/rooms/${roomId}?after=0`, recipient.sessionId);
  if (!Array.isArray(history.gifts) || history.gifts.length !== 1) {
    throw new Error(`Gift history mismatch: ${JSON.stringify(history)}`);
  }
  if (history.gifts[0]?.recipient_user_id !== String(recipient.id)) {
    throw new Error('Gift history recipient mismatch.');
  }

  const selfGift = await rawRequest('POST', `/gifts/rooms/${roomId}/send`, sender.sessionId, {
    recipientUserId: Number(sender.id),
    giftCode: 'rose',
    clientGiftId: `gift-e2e-self-${randomUUID()}`,
  });
  if (selfGift.status !== 400) {
    throw new Error(`Self gift should be rejected with 400, got ${selfGift.status}.`);
  }

  await pool.query('update user_wallets set coin_balance=0 where user_id=$1', [sender.id]);
  for (let index = 0; index < 3; index += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2100));
    const freeSent = await request('POST', `/gifts/rooms/${roomId}/send`, sender.sessionId, {
      recipientUserId: Number(recipient.id),
      giftCode: 'free_wave',
      clientGiftId: `gift-e2e-free-${index}-${randomUUID()}`,
    });
    if (Number(freeSent.wallet?.coinBalance) !== 0) {
      throw new Error('Daily free gift must not spend coins.');
    }
    if (Number(freeSent.freeGiftAllowance?.remaining) !== 2 - index) {
      throw new Error(`Free gift allowance did not decrement: ${JSON.stringify(freeSent.freeGiftAllowance)}`);
    }
  }

  const afterFree = await request('GET', '/gifts/catalog', sender.sessionId);
  if (Number(afterFree.freeGiftAllowance?.remaining) !== 0) {
    throw new Error(`Free gift allowance should be exhausted: ${JSON.stringify(afterFree.freeGiftAllowance)}`);
  }
  if (Number(afterFree.wallet?.profileXp) !== 5) {
    throw new Error(`Three free gifts should add only 3 tiny profile XP: ${JSON.stringify(afterFree.wallet)}`);
  }

  await new Promise((resolve) => setTimeout(resolve, 2100));
  const fourthFree = await rawRequest('POST', `/gifts/rooms/${roomId}/send`, sender.sessionId, {
    recipientUserId: Number(recipient.id),
    giftCode: 'free_wave',
    clientGiftId: `gift-e2e-free-limit-${randomUUID()}`,
  });
  if (fourthFree.status !== 400) {
    throw new Error(`Fourth daily free gift should be rejected with 400, got ${fourthFree.status}.`);
  }

  await new Promise((resolve) => setTimeout(resolve, 2100));
  const insufficient = await rawRequest('POST', `/gifts/rooms/${roomId}/send`, sender.sessionId, {
    recipientUserId: Number(recipient.id),
    giftCode: 'crown',
    clientGiftId: `gift-e2e-empty-${randomUUID()}`,
  });
  if (insufficient.status !== 400) {
    throw new Error(`Insufficient balance should be 400, got ${insufficient.status}.`);
  }

  const giftCount = await pool.query(
    'select count(*)::int as count from room_gifts where room_id=$1',
    [roomId],
  );
  if (Number(giftCount.rows[0]?.count) !== 4) {
    throw new Error('Rejected/replayed gift created an unexpected room_gifts count.');
  }

  const matchesAfter = await pool.query('select count(*)::int as count from matches');
  if (Number(matchesAfter.rows[0]?.count) !== Number(matchesBefore.rows[0]?.count)) {
    throw new Error('Sending a gift changed match records.');
  }

  await pool.query(`update rooms set status='closed',closed_at=now() where id=$1`, [roomId]);
  await pool.query(`update room_members set left_at=coalesce(left_at,now()) where room_id=$1`, [roomId]);
  await new Promise((resolve) => setTimeout(resolve, 2100));
  const closedSend = await rawRequest('POST', `/gifts/rooms/${roomId}/send`, sender.sessionId, {
    recipientUserId: Number(recipient.id),
    giftCode: 'coffee',
    clientGiftId: `gift-e2e-closed-${randomUUID()}`,
  });
  if (closedSend.ok || ![400, 403].includes(closedSend.status)) {
    throw new Error(`Closed-room gift must be rejected, got ${closedSend.status}.`);
  }

  console.log('✅ MEET6 GROUP CHAT GIFTS + XP REWARDS E2E PASS');
  console.log('Rules: paid gifts + 3 daily free gifts + tiny free XP + profile XP + idempotency + no self/closed/insufficient gift + matching unaffected');

  await pool.query('delete from wallet_transactions where reference_type=$1 and reference_id in (select id from room_gifts where room_id=$2)', ['room_gift', roomId]);
  await pool.query('delete from room_gifts where room_id=$1', [roomId]);
  await pool.query('delete from user_daily_gift_usage where user_id=any($1::bigint[])', [ids]);
  await pool.query('delete from premium_grants where user_id=any($1::bigint[]) and source=$2', [ids, 'xp_reward']);
  await pool.query('delete from user_xp_reward_claims where user_id=any($1::bigint[])', [ids]);
  for (const userId of ids) {
    const previous = walletSnapshot.get(String(userId));
    if (!previous) continue;
    await pool.query(
      `update user_wallets set
         coin_balance=$2,gift_xp=$3,generosity_xp=$4,profile_xp=$5,gifts_received=$6,gifts_sent=$7,updated_at=now()
       where user_id=$1`,
      [
        userId,
        Number(previous.coin_balance),
        Number(previous.gift_xp),
        Number(previous.generosity_xp),
        Number(previous.profile_xp),
        Number(previous.gifts_received),
        Number(previous.gifts_sent),
      ],
    );
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end().catch(() => undefined);
    redis.disconnect();
  });