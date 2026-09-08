import process from 'node:process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';
import Redis from 'ioredis';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverDir = path.resolve(__dirname, '..');
dotenv.config({ path: path.resolve(serverDir, '../.env') });
dotenv.config({ path: path.resolve(serverDir, '.env'), override: false });

if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required.');
if (!process.env.REDIS_URL) throw new Error('REDIS_URL is required.');

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const redis = new Redis(process.env.REDIS_URL, { maxRetriesPerRequest: 2 });

function assert(condition, message) {
  if (!condition) throw new Error(`TABU E2E FAIL: ${message}`);
}

function normalize(value) {
  return String(value ?? '')
    .normalize('NFKC')
    .toLocaleLowerCase('tr-TR')
    .replace(/[’']/g, "'")
    .replace(/[^\p{L}\p{N}'-]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function containsExact(text, needle) {
  const n = normalize(needle);
  return n.length > 0 && (` ${normalize(text)} `).includes(` ${n} `);
}

try {
  const tables = await pool.query(
    `select to_regclass('public.tabu_words') words,
            to_regclass('public.tabu_forbidden_words') forbidden,
            to_regclass('public.tabu_word_history') history,
            to_regclass('public.tabu_game_xp_events') xp_events,
            to_regclass('public.tabu_matchmaking_queue') queue`,
  );
  const t = tables.rows[0];
  assert(
    t.words && t.forbidden && t.history && t.xp_events && t.queue,
    'Tabu migration tabloları eksik.',
  );

  const words = await pool.query(
    `select w.id::text,w.word,w.category,count(f.id)::int forbidden_count
     from tabu_words w
     left join tabu_forbidden_words f on f.tabu_word_id=w.id
     where w.enabled=true
     group by w.id,w.word,w.category
     order by w.id`,
  );
  assert(
    words.rowCount >= 1000,
    `1000 kelimelik seed yüklenmedi. Aktif sayı: ${words.rowCount}`,
  );
  assert(
    words.rows.every((row) => row.forbidden_count === 4),
    'Her aktif kelimede tam 4 yasaklı kelime olmalı.',
  );

  const categories = new Set(words.rows.map((row) => row.category));
  assert(categories.size >= 10, `Kategori sayısı düşük: ${categories.size}`);

  const duplicate = await pool.query(
    `select lower(word),count(*)::int c
     from tabu_words
     group by lower(word)
     having count(*)>1`,
  );
  assert(duplicate.rowCount === 0, 'Aynı Tabu kelimesi birden fazla kayıtlı.');

  const invalidForbidden = await pool.query(
    `select w.word
     from tabu_words w
     join tabu_forbidden_words f on f.tabu_word_id=w.id
     where lower(trim(w.word))=lower(trim(f.word))
     limit 1`,
  );
  assert(
    invalidForbidden.rowCount === 0,
    'Hedef kelime kendi yasaklı listesinde bulunuyor.',
  );

  const lockKey = `e2e:tabu:first-correct:${Date.now()}`;
  const attempts = await Promise.all(
    Array.from({ length: 20 }, (_, i) =>
      redis.set(lockKey, `guesser-${i}`, 'EX', 15, 'NX'),
    ),
  );
  const winners = attempts.filter((value) => value === 'OK').length;
  assert(
    winners === 1,
    `Atomik ilk doğru kilidi tek kazanan üretmedi: ${winners}`,
  );
  await redis.del(lockKey);

  const normalizationSamples = [
    ['SABAH!', 'sabah', true],
    ['sabahları', 'sabah', false],
    ['Bir fincan alırım.', 'fincan', true],
    ['fincancı', 'fincan', false],
    ['KAFE, çok kalabalık.', 'kafe', true],
    ['fast food severim', 'fast food', true],
    ['İÇECEK', 'içecek', true],
  ];
  for (const [text, needle, expected] of normalizationSamples) {
    assert(
      containsExact(text, needle) === expected,
      `Kelime sınırı testi başarısız: ${text} / ${needle}`,
    );
  }

  console.log(
    `TABU E2E OK: ${words.rowCount} aktif kelime, ${categories.size} kategori, 4 yasaklı/kelime, Redis NX tek-kazanan, NFKC TR kelime sınırı.`,
  );
} finally {
  await redis.quit().catch(() => undefined);
  await pool.end();
}
