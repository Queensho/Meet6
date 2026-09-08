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
if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');

const seedPath = path.resolve(serverDir, 'seeds/tabu_words.tr.json');
const rows = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
if (!Array.isArray(rows)) throw new Error('Tabu seed JSON bir dizi olmalı.');

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const client = await pool.connect();
try {
  await client.query('begin');
  for (const item of rows) {
    const word = String(item.word ?? '').trim();
    const category = String(item.category ?? 'genel').trim() || 'genel';
    const difficulty = String(item.difficulty ?? 'normal').trim() || 'normal';
    const forbidden = Array.isArray(item.forbidden)
      ? item.forbidden.map((v) => String(v).trim()).filter(Boolean).slice(0, 4)
      : [];
    if (!word || forbidden.length !== 4) throw new Error(`Geçersiz Tabu seed: ${word || '<boş>'}`);
    const inserted = await client.query(
      `insert into tabu_words(word,category,difficulty,enabled)
       values($1,$2,$3,true)
       on conflict(lower(word)) do update set category=excluded.category,difficulty=excluded.difficulty,enabled=true
       returning id`,
      [word, category, difficulty],
    );
    const id = inserted.rows[0].id;
    await client.query('delete from tabu_forbidden_words where tabu_word_id=$1', [id]);
    for (const banned of forbidden) {
      await client.query(
        'insert into tabu_forbidden_words(tabu_word_id,word) values($1,$2) on conflict do nothing',
        [id, banned],
      );
    }
  }
  await client.query('commit');
  console.log(`imported ${rows.length} Tabu words`);
} catch (error) {
  await client.query('rollback');
  throw error;
} finally {
  client.release();
  await pool.end();
}
