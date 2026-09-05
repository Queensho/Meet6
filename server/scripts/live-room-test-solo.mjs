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

const targetInput = (process.argv[2] ?? '').trim();
const TEST_PREFIX = '+999000000';
const fillers = [
  { phone: `${TEST_PREFIX}001`, name: 'Test Ada', gender: 'Kadın', birthDate: '1999-04-11', avatar: 1 },
  { phone: `${TEST_PREFIX}002`, name: 'Test Bora', gender: 'Erkek', birthDate: '1997-08-23', avatar: 2 },
  { phone: `${TEST_PREFIX}003`, name: 'Test Ece', gender: 'Kadın', birthDate: '2000-02-16', avatar: 3 },
  { phone: `${TEST_PREFIX}004`, name: 'Test Mert', gender: 'Erkek', birthDate: '1998-11-05', avatar: 4 },
  { phone: `${TEST_PREFIX}005`, name: 'Test Zeynep', gender: 'Kadın', birthDate: '1999-06-21', avatar: 5 },
];

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

function assertTarget(value) {
  if (!value) {
    throw new Error('Kullanıcı gerekli. Örnek: npm run test:room-solo -- 1 veya +905XXXXXXXXX');
  }
  if (!/^\d+$/.test(value) && (!value.startsWith('+') || value.length < 10)) {
    throw new Error('Kullanıcı ID veya +90 ile başlayan telefon gir.');
  }
  if (value.startsWith(TEST_PREFIX)) {
    throw new Error('Test kullanıcı hedef olamaz.');
  }
}

async function resolveTarget(client) {
  const byId = /^\d+$/.test(targetInput);
  const result = await client.query(
    `select u.id::text,u.phone_e164,p.display_name,p.profile_completed
     from users u
     left join profiles p on p.user_id=u.id
     where ${byId ? 'u.id=$1::bigint' : 'u.phone_e164=$1'}
     limit 1`,
    [targetInput],
  );
  const user = result.rows[0];
  if (!user) throw new Error('Kullanıcı bulunamadı.');
  if (user.profile_completed !== true) throw new Error('Kullanıcı profilini tamamlamamış.');
  return user;
}

async function runtimeRoomDuration(client) {
  const table = await client.query(
    `select to_regclass('public.app_runtime_settings')::text as table_name`,
  );
  if (!table.rows[0]?.table_name) return 15;
  const settings = await client.query(
    `select room_duration_minutes from app_runtime_settings where id=1`,
  );
  return Number(settings.rows[0]?.room_duration_minutes ?? 15);
}

async function closeStaleMemberships(client, userIds) {
  if (!userIds.length) return;
  await client.query(
    `update room_members rm
     set left_at=coalesce(r.closed_at,now())
     from rooms r
     where rm.room_id=r.id
       and rm.user_id=any($1::bigint[])
       and rm.left_at is null
       and r.status='closed'`,
    [userIds],
  );
}

async function upsertFillers(client) {
  const ids = [];
  for (const filler of fillers) {
    const user = await client.query(
      `insert into users(phone_e164,status,last_seen_at,updated_at)
       values($1,'active',now(),now())
       on conflict(phone_e164) do update set
         status='active',last_seen_at=now(),updated_at=now()
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
         41.0082,28.9784,'Meet6 test hesabı','Yazılı sohbeti test ediyorum.',
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
         looking_for='Herkes',min_age=18,max_age=65,distance_km=500,
         purpose='Yeni insanlarla tanışma',updated_at=now()`,
      [userId],
    );
  }
  return ids;
}

async function main() {
  assertTarget(targetInput);
  const client = await pool.connect();
  try {
    await client.query('begin');
    await client.query('select pg_advisory_xact_lock(606061)');

    const target = await resolveTarget(client);
    await closeStaleMemberships(client, [target.id]);

    const active = await client.query(
      `select r.id::text as room_id
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id=$1
         and rm.left_at is null
         and r.status in ('active','selection')
       limit 1`,
      [target.id],
    );
    if (active.rows[0]?.room_id) {
      throw new Error(`Kullanıcı zaten aktif odada: ${active.rows[0].room_id}`);
    }

    const fillerIds = await upsertFillers(client);
    await closeStaleMemberships(client, fillerIds);

    const fillerOpen = await client.query(
      `select distinct r.id::text as room_id
       from room_members rm
       join rooms r on r.id=rm.room_id
       where rm.user_id=any($1::bigint[])
         and rm.left_at is null
         and r.status in ('active','selection')`,
      [fillerIds],
    );
    if (fillerOpen.rowCount) {
      throw new Error(
        `Önceki test odası hâlâ açık (${fillerOpen.rows.map((row) => row.room_id).join(', ')}).`,
      );
    }

    const durationMinutes = await runtimeRoomDuration(client);
    const room = await client.query(
      `insert into rooms(
         status,started_at,ends_at,room_duration_minutes,room_mode
       ) values(
         'active',now(),now()+($1::int * interval '1 minute'),$1,'text'
       ) returning id::text`,
      [durationMinutes],
    );
    const roomId = room.rows[0].id;
    const allIds = [target.id, ...fillerIds];

    for (const userId of allIds) {
      await client.query(
        `insert into room_members(room_id,user_id) values($1,$2)`,
        [roomId, userId],
      );
    }

    await client.query(
      `delete from matchmaking_queue where user_id=any($1::bigint[])`,
      [allIds],
    );

    await client.query(
      `insert into room_messages(room_id,sender_user_id,body)
       values($1,$2,'Selam 👋')`,
      [roomId, fillerIds[0]],
    );

    await client.query(
      `insert into notifications(user_id,type,title,body,data)
       values($1,'room_found','Odan hazır!','5 kişi seni yazılı sohbette bekliyor.',
              jsonb_build_object('roomId',$2::text,'forceDelivery',true))`,
      [target.id, roomId],
    );

    await client.query('commit');

    console.log(`✅ Yazılı test odası açıldı: room_id=${roomId}`);
    console.log(`✅ Kullanıcı: ${target.display_name ?? target.phone_e164} (${target.id})`);
    console.log('✅ Üye sayısı: 6 (sen + 5 test kullanıcı)');
    console.log(`✅ Süre: ${durationMinutes} dk`);
    console.log('✅ Test Ada ilk mesajı yazdı: Selam 👋');
    console.log('✅ Oda modu: text');
    console.log('Test bitince oda kapandıktan sonra: npm run test:room-clear');
  } catch (error) {
    await client.query('rollback').catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
}

main()
  .catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end().catch(() => undefined);
  });
