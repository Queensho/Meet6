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

const rawTarget = (process.argv[2] ?? '').trim();
const unlimitedBalance = 2_000_000_000;

function normalizePhone(value) {
  const digits = value.replace(/\D/g, '');
  if (/^0\d{10}$/.test(digits)) return `+90${digits.slice(1)}`;
  if (/^90\d{10}$/.test(digits)) return `+${digits}`;
  if (/^\d{10}$/.test(digits)) return `+90${digits}`;
  if (value.startsWith('+') && digits.length >= 10) return `+${digits}`;
  return null;
}

async function main() {
  if (!rawTarget) {
    throw new Error('Kullanıcı ID veya telefon gerekli. Örnek: npm run admin:coins-unlimited -- 05XXXXXXXXX');
  }

  const byId = /^\d+$/.test(rawTarget) && rawTarget.length < 10;
  const phone = byId ? null : normalizePhone(rawTarget);
  if (!byId && !phone) throw new Error('Telefon numarası geçersiz.');

  const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
  const client = await pool.connect();
  try {
    await client.query('begin');
    const userResult = await client.query(
      byId
        ? `select u.id::text,u.phone_e164,p.display_name
           from users u left join profiles p on p.user_id=u.id
           where u.id=$1::bigint limit 1`
        : `select u.id::text,u.phone_e164,p.display_name
           from users u left join profiles p on p.user_id=u.id
           where u.phone_e164=$1 limit 1`,
      [byId ? rawTarget : phone],
    );
    const user = userResult.rows[0];
    if (!user) throw new Error('Kullanıcı bulunamadı.');

    await client.query(
      `insert into user_wallets(user_id,coin_balance,unlimited_coins)
       values($1,$2,true)
       on conflict(user_id) do update set
         unlimited_coins=true,
         coin_balance=greatest(user_wallets.coin_balance,$2),
         updated_at=now()`,
      [user.id, unlimitedBalance],
    );

    await client.query('commit');
    console.log(`✅ Sınırsız jeton aktif: ${user.display_name ?? user.phone_e164} (user_id=${user.id})`);
    console.log(`✅ Sabit bakiye: ${unlimitedBalance.toLocaleString('tr-TR')} jeton; harcamalarda düşmez.`);
  } catch (error) {
    await client.query('rollback').catch(() => undefined);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
