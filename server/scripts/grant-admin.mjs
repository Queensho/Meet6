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

const phone = (process.argv[2] ?? '').replace(/\s+/g, '');
const role = process.argv[3] ?? 'super_admin';
const validRoles = new Set(['super_admin', 'moderator', 'support']);

if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
if (!phone.startsWith('+') || phone.length < 10) {
  throw new Error('Usage: npm run admin:grant -- +905XXXXXXXXX [super_admin|moderator|support]');
}
if (!validRoles.has(role)) throw new Error(`Invalid role: ${role}`);

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
try {
  const user = await pool.query(
    'select id::text, phone_e164 from users where phone_e164=$1',
    [phone],
  );
  if (!user.rowCount) {
    throw new Error('Bu telefonla kayıtlı Meet6 kullanıcısı bulunamadı. Önce normal uygulamadan OTP ile hesap oluştur.');
  }
  const userId = user.rows[0].id;
  await pool.query(
    `insert into admin_users(user_id, role, active, updated_at)
     values($1, $2, true, now())
     on conflict(user_id) do update set role=excluded.role, active=true, updated_at=now()`,
    [userId, role],
  );
  console.log(`Admin yetkisi verildi: user_id=${userId} role=${role}`);
} finally {
  await pool.end();
}
