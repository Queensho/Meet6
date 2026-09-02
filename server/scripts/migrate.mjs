import fs from 'node:fs';
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

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is required');
}

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

try {
  await pool.query(`
    create table if not exists schema_migrations (
      name text primary key,
      applied_at timestamptz not null default now()
    )
  `);

  const sqlDir = path.resolve(serverDir, 'sql');
  const files = fs.readdirSync(sqlDir).filter((name) => name.endsWith('.sql')).sort();

  for (const name of files) {
    const exists = await pool.query('select 1 from schema_migrations where name = $1', [name]);
    if (exists.rowCount) {
      console.log(`skip ${name}`);
      continue;
    }

    const sql = fs.readFileSync(path.join(sqlDir, name), 'utf8');
    const client = await pool.connect();
    try {
      await client.query('begin');
      await client.query(sql);
      await client.query('insert into schema_migrations(name) values($1)', [name]);
      await client.query('commit');
      console.log(`applied ${name}`);
    } catch (error) {
      await client.query('rollback');
      throw error;
    } finally {
      client.release();
    }
  }
} finally {
  await pool.end();
}
