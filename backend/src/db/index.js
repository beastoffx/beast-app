const { DatabaseSync } = require('node:sqlite');
const { AsyncLocalStorage } = require('node:async_hooks');
const fs = require('fs');
const path = require('path');
const config = require('../config');

const txStorage = new AsyncLocalStorage();
let dbInstance = null;
let pgPoolInstance = null;

/**
 * Determine whether the application runtime should use Supabase PostgreSQL.
 * True when DATABASE_URL is present and runtime is production or explicitly requested via USE_POSTGRES=true.
 */
function isUsingPostgres() {
  return Boolean(config.databaseUrl) && (config.nodeEnv === 'production' || process.env.USE_POSTGRES === 'true');
}

/**
 * Human-readable description of active database target for startup logging and diagnostics.
 */
function getDbTargetDescription() {
  if (isUsingPostgres()) {
    try {
      const u = new URL(config.databaseUrl);
      return `Supabase PostgreSQL (${u.hostname}:${u.port || 5432}${u.pathname})`;
    } catch (_) {
      return 'Supabase PostgreSQL (DATABASE_URL)';
    }
  }
  return `SQLite (${config.dbPath})`;
}

/**
 * SQLite Connection Manager (Used for local offline development and automated test suites)
 */
function getDb(customPath = null) {
  if (dbInstance && !customPath) {
    return dbInstance;
  }

  const targetPath = customPath || config.dbPath;

  if (targetPath !== ':memory:') {
    const dir = path.dirname(targetPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  const db = new DatabaseSync(targetPath);

  // Performance and integrity pragmas
  db.exec('PRAGMA foreign_keys = ON;');
  db.exec('PRAGMA busy_timeout = 5000;');
  if (targetPath !== ':memory:') {
    db.exec('PRAGMA journal_mode = WAL;');
    db.exec('PRAGMA synchronous = NORMAL;');
  }

  if (!customPath) {
    dbInstance = db;
  }
  return db;
}

/**
 * PostgreSQL Connection Pool Manager (Used for production on Render)
 */
function getPgPool() {
  if (!config.databaseUrl) {
    return null;
  }
  if (!pgPoolInstance) {
    const { Pool } = require('pg');
    let servername;
    try {
      const u = new URL(config.databaseUrl);
      servername = u.hostname;
    } catch (_) {}

    pgPoolInstance = new Pool({
      connectionString: config.databaseUrl,
      ssl: {
        rejectUnauthorized: false,
        ...(servername ? { servername } : {})
      },
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000
    });

    pgPoolInstance.on('error', (err) => {
      console.error('[PG POOL] Unexpected error on idle client:', err.message);
    });
  }
  return pgPoolInstance;
}

async function asyncPgQuery(text, params = []) {
  const pool = getPgPool();
  if (!pool) {
    throw new Error('PostgreSQL pool is not initialized. DATABASE_URL is missing.');
  }
  return pool.query(text, params);
}

/**
 * Transparent SQL Translator: SQLite -> PostgreSQL Dialect
 * - Converts positional '?' placeholders to '$1, $2, ...' (respecting quotes and comments)
 * - Converts SQLite datetime('now') -> CURRENT_TIMESTAMP
 * - Converts SQLite datetime('now', '-N seconds/minutes') -> (CURRENT_TIMESTAMP - INTERVAL 'N seconds/minutes')
 * - Converts SQLite date('now') -> CURRENT_DATE
 * - Converts SQLite LIKE -> PostgreSQL ILIKE for case-insensitive matching
 * - Converts boolean literals (is_active = 1/0, etc.) -> is_active = true/false
 * - Converts SQLite INSERT OR REPLACE for teacher_assignments -> PostgreSQL ON CONFLICT DO UPDATE
 */
function toPgSql(sql) {
  let inSingleQuote = false;
  let inDoubleQuote = false;
  let inLineComment = false;
  let inBlockComment = false;
  let paramIndex = 1;
  let out = '';

  for (let i = 0; i < sql.length; i++) {
    const ch = sql[i];
    const nextCh = sql[i + 1];

    if (inLineComment) {
      out += ch;
      if (ch === '\n') inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      out += ch;
      if (ch === '*' && nextCh === '/') {
        out += nextCh;
        i++;
        inBlockComment = false;
      }
      continue;
    }
    if (inSingleQuote) {
      out += ch;
      if (ch === "'") {
        if (nextCh === "'") {
          out += nextCh;
          i++;
        } else {
          inSingleQuote = false;
        }
      }
      continue;
    }
    if (inDoubleQuote) {
      out += ch;
      if (ch === '"') inDoubleQuote = false;
      continue;
    }

    if (ch === '-' && nextCh === '-') {
      inLineComment = true;
      out += '--';
      i++;
      continue;
    }
    if (ch === '/' && nextCh === '*') {
      inBlockComment = true;
      out += '/*';
      i++;
      continue;
    }

    if (ch === "'") {
      inSingleQuote = true;
      out += ch;
      continue;
    }
    if (ch === '"') {
      inDoubleQuote = true;
      out += ch;
      continue;
    }

    if (ch === '?') {
      out += `$${paramIndex++}`;
      continue;
    }

    out += ch;
  }

  // Dialect translations
  out = out.replace(/\bdatetime\('now',\s*'\+(\d+)\s*(seconds|minutes|hours|days)'\)/gi, "(CURRENT_TIMESTAMP + INTERVAL '$1 $2')");
  out = out.replace(/\bdatetime\('now',\s*'-(\d+)\s*(seconds|minutes|hours|days)'\)/gi, "(CURRENT_TIMESTAMP - INTERVAL '$1 $2')");
  out = out.replace(/\bdatetime\('now'\)/gi, "CURRENT_TIMESTAMP");
  out = out.replace(/\bdate\('now'\)/gi, "CURRENT_DATE");

  // Boolean column literals in SET or WHERE clauses
  out = out.replace(/\b(is_active|is_verified|phone_verified|is_current|is_pinned|is_published|is_read)\s*=\s*1\b/gi, '$1 = true');
  out = out.replace(/\b(is_active|is_verified|phone_verified|is_current|is_pinned|is_published|is_read)\s*=\s*0\b/gi, '$1 = false');

  // Case-insensitive LIKE to ILIKE in PostgreSQL
  out = out.replace(/\bLIKE\b/g, 'ILIKE');

  // Upsert for teacher_assignments
  out = out.replace(
    /INSERT\s+OR\s+REPLACE\s+INTO\s+teacher_assignments\s*\(([^)]+)\)\s*VALUES\s*\(([^)]+)\)/i,
    'INSERT INTO teacher_assignments ($1) VALUES ($2) ON CONFLICT (teacher_id, batch_id, subject_id, academic_session_id) DO UPDATE SET assigned_at = CURRENT_TIMESTAMP'
  );

  return out;
}

function sanitizeParams(params) {
  if (!params || !Array.isArray(params)) return [];
  return params.map(p => p === undefined ? null : p);
}

function query(sql, params = []) {
  if (isUsingPostgres()) {
    const activeClient = txStorage.getStore() || getPgPool();
    const text = toPgSql(sql);
    const values = sanitizeParams(params);
    return activeClient.query(text, values).then(res => res.rows);
  }
  const db = getDb();
  const stmt = db.prepare(sql);
  return stmt.all(...params);
}

function get(sql, params = []) {
  if (isUsingPostgres()) {
    const activeClient = txStorage.getStore() || getPgPool();
    const text = toPgSql(sql);
    const values = sanitizeParams(params);
    return activeClient.query(text, values).then(res => res.rows[0] !== undefined ? res.rows[0] : undefined);
  }
  const db = getDb();
  const stmt = db.prepare(sql);
  return stmt.get(...params);
}

function run(sql, params = []) {
  if (isUsingPostgres()) {
    const activeClient = txStorage.getStore() || getPgPool();
    const text = toPgSql(sql);
    const values = sanitizeParams(params);
    return activeClient.query(text, values).then(res => ({
      changes: res.rowCount || 0,
      lastInsertRowid: null
    }));
  }
  const db = getDb();
  const stmt = db.prepare(sql);
  return stmt.run(...params);
}

function exec(sql) {
  if (isUsingPostgres()) {
    const activeClient = txStorage.getStore() || getPgPool();
    return activeClient.query(sql).then(() => {});
  }
  const db = getDb();
  return db.exec(sql);
}

function transaction(callback) {
  if (isUsingPostgres()) {
    return (async () => {
      const pool = getPgPool();
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const boundQuery = async (s, p = []) => {
          const res = await client.query(toPgSql(s), sanitizeParams(p));
          return res.rows;
        };
        const boundGet = async (s, p = []) => {
          const rows = await boundQuery(s, p);
          return rows[0] !== undefined ? rows[0] : undefined;
        };
        const boundRun = async (s, p = []) => {
          const res = await client.query(toPgSql(s), sanitizeParams(p));
          return { changes: res.rowCount || 0, lastInsertRowid: null };
        };

        const result = await txStorage.run(client, async () => {
          return await callback({ query: boundQuery, get: boundGet, run: boundRun });
        });
        await client.query('COMMIT');
        return result;
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    })();
  }

  const db = getDb();
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = callback({ query, get, run });
    if (result && typeof result.then === 'function') {
      return result.then(
        (val) => {
          db.exec('COMMIT');
          return val;
        },
        (err) => {
          db.exec('ROLLBACK');
          throw err;
        }
      );
    }
    db.exec('COMMIT');
    return result;
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

function runMigrations(db) {
  try {
    const tableExists = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='users'").get();
    if (tableExists) {
      const userColumns = db.prepare("PRAGMA table_info(users)").all().map(c => c.name);
      if (!userColumns.includes('google_uid')) {
        db.exec("ALTER TABLE users ADD COLUMN google_uid TEXT;");
      }
      if (!userColumns.includes('phone_verified')) {
        db.exec("ALTER TABLE users ADD COLUMN phone_verified INTEGER NOT NULL DEFAULT 0;");
      }
      if (!userColumns.includes('status')) {
        db.exec("ALTER TABLE users ADD COLUMN status TEXT NOT NULL DEFAULT 'active';");
      }
      if (!userColumns.includes('last_login_at')) {
        db.exec("ALTER TABLE users ADD COLUMN last_login_at TEXT;");
      }

      // Upgrade check constraint to support 'super_admin' role if needed
      const userTableSql = db.prepare("SELECT sql FROM sqlite_master WHERE type='table' AND name='users'").get()?.sql || '';
      if (userTableSql && !userTableSql.includes('super_admin')) {
        db.exec("PRAGMA foreign_keys = OFF;");
        db.exec("DROP TABLE IF EXISTS users_migrated;");
        db.exec(`
          CREATE TABLE users_migrated (
            id TEXT PRIMARY KEY,
            google_uid TEXT UNIQUE,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT,
            role TEXT NOT NULL CHECK (role IN ('student', 'teacher', 'admin', 'super_admin', 'parent', 'staff')),
            name TEXT NOT NULL,
            phone TEXT,
            phone_verified INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending_activation', 'suspended', 'archived', 'expired')),
            avatar_url TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            last_login_at TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
          );
          INSERT INTO users_migrated (id, email, password_hash, role, name, phone, avatar_url, is_active, created_at, updated_at, google_uid, phone_verified, status, last_login_at)
          SELECT id, email, password_hash, role, name, phone, avatar_url, is_active, created_at, updated_at, google_uid, phone_verified, status, last_login_at FROM users;
          DROP TABLE users;
          ALTER TABLE users_migrated RENAME TO users;
          CREATE INDEX IF NOT EXISTS idx_users_google_uid ON users(google_uid);
          CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
          CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
          CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
        `);
        db.exec("PRAGMA foreign_keys = ON;");
      }
    }
  } catch (err) {
    console.error('[MIGRATION_ERROR]', err);
  }

  try {
    const stuTableExists = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='student_profiles'").get();
    if (stuTableExists) {
      const stuColumns = db.prepare("PRAGMA table_info(student_profiles)").all().map(c => c.name);
      if (!stuColumns.includes('subscription_status')) {
        db.exec("ALTER TABLE student_profiles ADD COLUMN subscription_status TEXT NOT NULL DEFAULT 'paid';");
      }
      if (!stuColumns.includes('access_start_date')) {
        db.exec("ALTER TABLE student_profiles ADD COLUMN access_start_date TEXT;");
      }
      if (!stuColumns.includes('access_end_date')) {
        db.exec("ALTER TABLE student_profiles ADD COLUMN access_end_date TEXT;");
      }
      if (!stuColumns.includes('resource_permissions_json')) {
        db.exec("ALTER TABLE student_profiles ADD COLUMN resource_permissions_json TEXT DEFAULT '{\"materials\": true, \"doubts\": true, \"exams\": true}';");
      }
    }
  } catch (_) {}

  try {
    const adminTableExists = db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='admin_profiles'").get();
    if (adminTableExists) {
      const adminColumns = db.prepare("PRAGMA table_info(admin_profiles)").all().map(c => c.name);
      if (!adminColumns.includes('admin_id_number')) {
        db.exec("ALTER TABLE admin_profiles ADD COLUMN admin_id_number TEXT;");
      }
      if (!adminColumns.includes('created_by')) {
        db.exec("ALTER TABLE admin_profiles ADD COLUMN created_by TEXT;");
      }
      db.exec("UPDATE admin_profiles SET admin_id_number = 'ADM-2027-00001' WHERE admin_id_number IS NULL OR admin_id_number = '';");
    }
  } catch (_) {}

  try {
    db.exec(`
      CREATE TABLE IF NOT EXISTS email_verifications (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        otp_hash TEXT NOT NULL,
        session_id TEXT UNIQUE NOT NULL,
        student_id_number TEXT NOT NULL,
        google_uid TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        is_verified INTEGER NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
      CREATE INDEX IF NOT EXISTS idx_email_verifications_session ON email_verifications(session_id);
      CREATE INDEX IF NOT EXISTS idx_email_verifications_email ON email_verifications(email);
    `);
  } catch (_) {}

  try {
    db.exec(`
      CREATE TABLE IF NOT EXISTS account_requests (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        google_uid TEXT,
        requested_role TEXT NOT NULL CHECK (requested_role IN ('student', 'teacher', 'admin')),
        status TEXT NOT NULL CHECK (status IN (
            'PENDING_TEACHER_REVIEW',
            'PENDING_ADMIN_REVIEW',
            'PENDING_SUPER_ADMIN_REVIEW',
            'APPROVED',
            'REJECTED'
        )),
        target_class_id TEXT REFERENCES classes(id) ON DELETE SET NULL,
        target_batch_id TEXT REFERENCES batches(id) ON DELETE SET NULL,
        target_session_id TEXT REFERENCES academic_sessions(id) ON DELETE SET NULL,
        qualification TEXT,
        department TEXT,
        notes TEXT,
        teacher_reviewer_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        teacher_reviewed_at TEXT,
        teacher_review_notes TEXT,
        admin_reviewer_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        admin_reviewed_at TEXT,
        admin_review_notes TEXT,
        super_admin_reviewer_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        super_admin_reviewed_at TEXT,
        super_admin_review_notes TEXT,
        rejection_reason TEXT,
        generated_student_id TEXT,
        created_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      );
      CREATE INDEX IF NOT EXISTS idx_account_requests_email ON account_requests(email);
      CREATE INDEX IF NOT EXISTS idx_account_requests_google_uid ON account_requests(google_uid);
      CREATE INDEX IF NOT EXISTS idx_account_requests_status ON account_requests(status);
      CREATE INDEX IF NOT EXISTS idx_account_requests_role ON account_requests(requested_role);
    `);
  } catch (_) {}
}

function initSchema(db = null) {
  if (isUsingPostgres()) {
    const pool = getPgPool();
    return pool.query('SELECT count(*) FROM users').then(res => {
      console.log(`[DB INIT] Supabase PostgreSQL verified. Central users count: ${res.rows[0].count}`);
    });
  }
  const database = db || getDb();
  runMigrations(database);
  const schemaPath = path.join(__dirname, 'schema.sql');
  const schemaSql = fs.readFileSync(schemaPath, 'utf8');
  database.exec(schemaSql);
  runMigrations(database);
  return Promise.resolve();
}

module.exports = {
  getDb,
  initSchema,
  query,
  get,
  run,
  exec,
  transaction,
  getPgPool,
  asyncPgQuery,
  isUsingPostgres,
  getDbTargetDescription,
  toPgSql
};
