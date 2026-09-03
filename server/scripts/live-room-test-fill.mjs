import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverDir = path.resolve(__dirname, '..');

dotenv.config({ path: path.resolve(serverDir, '../.env') });
dotenv.config({ path: path.resolve(serverDir, '.env'), override: false });

if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');

const mode = (process.argv[2] ?? 'fill').trim().toLowerCase();
const firstPhone = (process.argv[3] ?? '').replace(/\s+/g, '');
const secondPhone = (process.argv[4] ?? '').replace(/\s+/g, '');
const TEST_PREFIX = '+999000000';
const WAIT_MS = 2_000;
const TIMEOUT_MS = 10 * 60_000;

const fillers = [
  { phone: `${TEST_PREFIX}001`, name: 'Test Ada', gender: 'Kadın', birthDate: '1999-04-11', avatar: 1 },
  { phone: `${TEST_PREFIX}002`, name: 'Test Bora', gender: 'Erkek', birthDate: '1997-08-23', avatar: 2 },
  { phone: `${TEST_PREFIX}003`, name: 'Test Ece', gender: 'Kadın', birthDate: '2000-02-16', avatar: 3 },
  { phone: `${TEST_PREFIX}004`, name: 'Test Mert', gender: 'Erkek', birthDate: '1998-11-05', avatar: 4 },
];

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function assertPhone(phone, label) {
  if (!phone.startsWith('+') || phone.length < 10) {
    throw new Error(`${label} geçersiz. Örnek: +905XXXXXXXXX`);
  }
  if (phone.startsWith(TEST_PREFIX)) {
    throw new Error(`${label} test kullanıcı prefix'i olamaz.`);
  }
}

async function upsertFillers(client) {
  const ids = [];
  for (const filler of fillers) {
    const user = await client.query(
      `insert into users(phone_e164,status,last_seen_at,updated_at)
       values($1,'active',now(),now())
       on conflict(phone_e164) do update set
         status='active', last_seen_at=now(), updated_at=now()
       returning id::text`,
      [filler.phone],
    );
    const userId = user.rows[0].id;
    ids.push(userId);

    const avatarUrl = `https://www.meet6.com.tr/assets/assets/images/Avatar${filler.avatar}.png`;
    await client.query(
      `insert into profiles(
         user_id,display_name,birth_date,gender,bio,city,country,
         latitude,longitude,profile_prompt,profile_answer,
         interests,photo_urls,profile_completed,updated_at
       ) values(
         $1,$2,$3,$4,'Meet6 canlı oda test kullanıcısı','İstanbul','Türkiye',
         41.0082,28.9784,'Meet6 test hesabı','Oda akışını test ediyorum.',
         array['Sohbet','Müzik'],array[$5]::text[],true,now()
       )
       on conflict(user_id) do update set
         display_name=excluded.display_name,
         birth_date=excluded.birth_date,
         gender=excluded.gender,
         bio=excluded.bio,
         city=excluded.city,
         country=excluded.country,
         latitude=excluded.latitude,
         longitude=excluded.longitude,
         profile_prompt=excluded.profile_prompt,
         profile_answer=excluded.profile_answer,
         interests=excluded.interests,
         photo_urls=excluded.photo_urls,
         profile_completed=true,
         updated_at=now()`,
      [userId, filler.name, filler.birthDate, filler.gender, avatarUrl],
    );

    await client.query(
      `insert into matching_preferences(
         user_id,looking_for,min_age,max_age,distance_km,purpose,updated_at
       ) values($1,'Herkes',18,65,500,'Yeni insanlarla tanışma',now())
       on conflict(user_id) do update set
         looking_for='Herkes', min_age=18, max_age=65, distance_km=500,
         purpose='Yeni insanlarla tanışma', updated_at=now()`,
      [userId],
    );
  }
  return ids;
}

async function resolveRealUsers() {
  const result = await pool.query(
    `select u.id::text, u.phone_e164, p.display_name, p.profile_completed
     from users u
     left join profiles p on p.user_id=u.id
     where u.phone_e164 = any($1::text[])
     order by array_position($1::text[], u.phone_e164)`,
    [[firstPhone, secondPhone]],
  );
  if (result.rowCount !== 2) {
    const found = new Set(result.rows.map((row) => row.phone_e164));
    const missing = [firstPhone, secondPhone].filter((phone) => !found.has(phone));
    throw new Error(`Kayıtlı kullanıcı bulunamadı: ${missing.join(', ')}`);
  }
  for (const row of result.rows) {
    if (row.profile_completed !== true) {
      throw new Error(`${row.phone_e164} profilini tamamlamamış.`);
    }
  }
  return result.rows;
}

async function openRoomFor(userIds) {
  const check = await pool.query(
    `select rm.user_id::text, rm.room_id::text
     from room_members rm
     join rooms r on r.id=rm.room_id
     where rm.user_id = any($1::bigint[])
       and rm.left_at is null
       and coalesce(rm.admin_removed_at, null) is null
       and r.status in ('active','selection')`,
    [userIds],
  );
  return check.rows;
}

async function bothQueued(userIds) {
  const result = await pool.query(
    `select user_id::text from matchmaking_queue
     where user_id = any($1::bigint[])`,
    [userIds],
  );
  return result.rowCount === userIds.length;
}

async function createTestRoom(realUsers) {
  const client = await pool.connect();
  try {
    await client.query('begin');
    await client.query('select pg_advisory_xact_lock(606061)');

    const realIds = realUsers.map((row) => row.id);
    const queued = await client.query(
      `select user_id::text from matchmaking_queue
       where user_id = any($1::bigint[])
       for update`,
      [realIds],
    );
    if (queued.rowCount !== 2) {
      throw new Error('İki gerçek kullanıcı artık aynı anda kuyrukta değil. Tekrar deneyin.');
    }

    const existing = await client.query(
      `select rm.user_id::text, rm.room_id::text
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id = any($1::bigint[])
         and rm.left_at is null
         and r.status in ('active','selection')`,
      [realIds],
    );
    if (existing.rowCount) {
      throw new Error(`Gerçek kullanıcılardan biri zaten aktif odada: ${existing.rows[0].room_id}`);
    }

    const fillerIds = await upsertFillers(client);
    const fillerOpen = await client.query(
      `select distinct rm.room_id::text
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id = any($1::bigint[])
         and rm.left_at is null
         and r.status in ('active','selection')`,
      [fillerIds],
    );
    if (fillerOpen.rowCount) {
      throw new Error(
        `Önceki test odası hâlâ açık (${fillerOpen.rows.map((r) => r.room_id).join(', ')}). Oda kapanınca tekrar çalıştır.`,
      );
    }

    const settings = await client.query(
      `select room_duration_minutes from app_runtime_settings where id=1`,
    );
    const durationMinutes = Number(settings.rows[0]?.room_duration_minutes ?? 15);

    const room = await client.query(
      `insert into rooms(status,started_at,ends_at)
       values('active',now(),now() + ($1::int * interval '1 minute'))
       returning id::text`,
      [durationMinutes],
    );
    const roomId = room.rows[0].id;
    const allIds = [...realIds, ...fillerIds];

    for (const userId of allIds) {
      await client.query(
        `insert into room_members(room_id,user_id) values($1,$2)`,
        [roomId, userId],
      );
    }

    await client.query(
      `delete from matchmaking_queue where user_id = any($1::bigint[])`,
      [allIds],
    );

    await client.query(
      `insert into room_messages(room_id,sender_user_id,body)
       values($1,null,$2)`,
      [roomId, `Canlı test odası hazır. 2 gerçek + 4 test kullanıcı — ${durationMinutes} dakika.`],
    );

    for (const real of realUsers) {
      await client.query(
        `insert into notifications(user_id,type,title,body,data)
         values($1,'room_found','Odan hazır!','6 kişilik canlı test odan hazır.',
                jsonb_build_object('roomId',$2::text,'forceDelivery',true))`,
        [real.id, roomId],
      );
    }

    await client.query('commit');
    return { roomId, durationMinutes, fillerIds };
  } catch (error) {
    await client.query('rollback').catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
}

async function clearFillers() {
  const open = await pool.query(
    `select distinct r.id::text
     from users u
     join room_members rm on rm.user_id=u.id
     join rooms r on r.id=rm.room_id
     where u.phone_e164 like $1
       and rm.left_at is null
       and r.status in ('active','selection')`,
    [`${TEST_PREFIX}%`],
  );
  if (open.rowCount) {
    throw new Error(
      `Test odası hâlâ açık (${open.rows.map((r) => r.id).join(', ')}). Oda kapanmadan test kullanıcılarını silmiyorum.`,
    );
  }
  const result = await pool.query(
    `delete from users where phone_e164 like $1 returning phone_e164`,
    [`${TEST_PREFIX}%`],
  );
  console.log(`Temizlendi: ${result.rowCount} test kullanıcı.`);
}

try {
  if (mode === 'clear') {
    await clearFillers();
  } else {
    assertPhone(firstPhone, '1. telefon');
    assertPhone(secondPhone, '2. telefon');
    if (firstPhone === secondPhone) throw new Error('İki farklı gerçek kullanıcı gerekli.');

    const users = await resolveRealUsers();
    const realIds = users.map((row) => row.id);
    const open = await openRoomFor(realIds);
    if (open.length) {
      throw new Error(`Kullanıcılardan biri zaten aktif odada: ${open[0].room_id}`);
    }

    console.log('Canlı test hazır. Şimdi bu iki kullanıcı uygulamada Oda Ara’ya bassın:');
    for (const user of users) console.log(`- ${user.display_name ?? user.phone_e164}`);
    console.log('İki kullanıcı da kuyruğa girince 4 test kullanıcı eklenip oda otomatik kurulacak.');

    const startedAt = Date.now();
    while (!(await bothQueued(realIds))) {
      if (Date.now() - startedAt > TIMEOUT_MS) {
        throw new Error('10 dakika içinde iki kullanıcı aynı anda kuyruğa girmedi. Test iptal edildi.');
      }
      process.stdout.write('.');
      await sleep(WAIT_MS);
    }
    process.stdout.write('\n');

    const created = await createTestRoom(users);
    console.log(`✅ Canlı test odası açıldı: room_id=${created.roomId}`);
    console.log(`✅ Üye sayısı: 6 (2 gerçek + 4 test)`);
    console.log(`✅ Süre: ${created.durationMinutes} dk`);
    console.log('✅ İki gerçek kullanıcıya “Odan hazır!” push bildirimi kuyruğa eklendi.');
    console.log('Test bitince ve oda kapandıktan sonra: npm run test:room-clear');
  }
} finally {
  await pool.end();
}
