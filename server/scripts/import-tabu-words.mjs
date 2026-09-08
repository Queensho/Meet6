import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import pg from 'pg';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const serverDir = path.resolve(__dirname, '..');
const seedsDir = path.resolve(serverDir, 'seeds');
dotenv.config({ path: path.resolve(serverDir, '../.env') });
dotenv.config({ path: path.resolve(serverDir, '.env'), override: false });
if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');

const difficultyMap = new Map([
  ['easy', 'kolay'],
  ['medium', 'normal'],
  ['hard', 'zor'],
  ['kolay', 'kolay'],
  ['normal', 'normal'],
  ['zor', 'zor'],
]);

function normalizeSeedRows(parsed, source) {
  const rows = Array.isArray(parsed)
    ? parsed
    : parsed && typeof parsed === 'object' && Array.isArray(parsed.words)
      ? parsed.words
      : null;
  if (!rows) throw new Error(`Tabu seed biçimi geçersiz: ${source}`);
  return rows;
}

function loadPackedSeedRows() {
  const packedFiles = fs
    .readdirSync(seedsDir)
    .filter((name) => /^tabu_words\.pack\.b64\.\d{2}$/i.test(name))
    .sort();
  if (!packedFiles.length) return null;

  for (let i = 0; i < packedFiles.length; i += 1) {
    const expected = `tabu_words.pack.b64.${String(i + 1).padStart(2, '0')}`;
    if (packedFiles[i] !== expected) {
      throw new Error(`Tabu packed seed parçası eksik: ${expected}`);
    }
  }

  const encoded = packedFiles
    .map((name) => fs.readFileSync(path.join(seedsDir, name), 'utf8').trim())
    .join('');
  if (!encoded) throw new Error('Tabu packed seed boş.');

  try {
    const compressed = Buffer.from(encoded, 'base64');
    const json = zlib.gunzipSync(compressed).toString('utf8');
    return normalizeSeedRows(JSON.parse(json), packedFiles.join(','));
  } catch (error) {
    throw new Error(`Tabu packed seed açılamadı: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function loadSeedRows() {
  const packed = loadPackedSeedRows();
  if (packed) return packed;

  const shardFiles = fs
    .readdirSync(seedsDir)
    .filter((name) => /^tabu_words_\d{2}\.tr\.json$/i.test(name))
    .sort();
  if (shardFiles.length > 0) {
    return shardFiles.flatMap((name) => {
      const filePath = path.join(seedsDir, name);
      return normalizeSeedRows(JSON.parse(fs.readFileSync(filePath, 'utf8')), name);
    });
  }

  const seedPath = path.resolve(seedsDir, 'tabu_words.tr.json');
  return normalizeSeedRows(JSON.parse(fs.readFileSync(seedPath, 'utf8')), path.basename(seedPath));
}

const rows = loadSeedRows();
if (!rows.length) throw new Error('Tabu seed boş.');

const prepared = [];
const seenWords = new Set();
for (const item of rows) {
  const word = String(item.word ?? '').normalize('NFKC').trim();
  const category = String(item.category ?? 'genel').normalize('NFKC').trim() || 'genel';
  const rawDifficulty = String(item.difficulty ?? 'normal').trim().toLocaleLowerCase('tr-TR');
  const difficulty = difficultyMap.get(rawDifficulty);
  const forbidden = Array.isArray(item.forbidden)
    ? item.forbidden.map((v) => String(v).normalize('NFKC').trim()).filter(Boolean)
    : [];
  const enabled = item.enabled !== false;

  if (!word) throw new Error('Geçersiz Tabu seed: boş hedef kelime.');
  if (!difficulty) throw new Error(`Geçersiz Tabu zorluğu: ${word} -> ${rawDifficulty}`);
  if (forbidden.length !== 4) throw new Error(`Geçersiz Tabu seed: ${word} için tam 4 yasaklı kelime gerekli.`);
  const forbiddenKeys = forbidden.map((v) => v.toLocaleLowerCase('tr-TR'));
  if (new Set(forbiddenKeys).size !== 4) throw new Error(`Geçersiz Tabu seed: ${word} yasaklı listesinde tekrar var.`);
  if (forbiddenKeys.includes(word.toLocaleLowerCase('tr-TR'))) throw new Error(`Geçersiz Tabu seed: ${word} kendi yasaklı listesinde.`);

  const wordKey = word.toLocaleLowerCase('tr-TR');
  if (seenWords.has(wordKey)) throw new Error(`Tekrarlanan Tabu hedef kelimesi: ${word}`);
  seenWords.add(wordKey);
  prepared.push({ word, category, difficulty, forbidden, enabled });
}

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const client = await pool.connect();
try {
  await client.query('begin');
  for (const item of prepared) {
    const inserted = await client.query(
      `insert into tabu_words(word,category,difficulty,enabled)
       values($1,$2,$3,$4)
       on conflict(lower(word)) do update
       set category=excluded.category,difficulty=excluded.difficulty,enabled=excluded.enabled
       returning id`,
      [item.word, item.category, item.difficulty, item.enabled],
    );
    const id = inserted.rows[0].id;
    await client.query('delete from tabu_forbidden_words where tabu_word_id=$1', [id]);
    for (const banned of item.forbidden) {
      await client.query(
        'insert into tabu_forbidden_words(tabu_word_id,word) values($1,$2)',
        [id, banned],
      );
    }
  }
  await client.query('commit');
  console.log(`imported ${prepared.length} Tabu words`);
} catch (error) {
  await client.query('rollback');
  throw error;
} finally {
  client.release();
  await pool.end();
}
