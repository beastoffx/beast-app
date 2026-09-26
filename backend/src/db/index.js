const { DatabaseSync } = require('node:sqlite');
const fs = require('fs');
const path = require('path');
const config = require('../config');

let dbInstance = null;

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
}

function initSchema(db = null) {
  const database = db || getDb();
  runMigrations(database);
  const schemaPath = path.join(__dirname, 'schema.sql');
  const schemaSql = fs.readFileSync(schemaPath, 'utf8');
  database.exec(schemaSql);
  runMigrations(database);
}

// PostgreSQL Adapter (Available when DATABASE_URL is configured)
let pgPoolInstance = null;
function getPgPool() {
  if (!config.databaseUrl) {
    return null;
  }
  if (!pgPoolInstance) {
    const { Pool } = require('pg');
    pgPoolInstance = new Pool({
      connectionString: config.databaseUrl,
      ssl: (config.nodeEnv === 'production' || (config.databaseUrl && config.databaseUrl.includes('supabase'))) ? { rejectUnauthorized: false } : false
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

// Helper methods with standard signatures
function query(sql, params = []) {
  const db = getDb();
  const stmt = db.prepare(sql);
  return stmt.all(...params);
}

function get(sql, params = []) {
  const db = getDb();
  const stmt = db.prepare(sql);
  return stmt.get(...params);
}

function run(sql, params = []) {
  const db = getDb();
  const stmt = db.prepare(sql);
  return stmt.run(...params);
}

function exec(sql) {
  const db = getDb();
  return db.exec(sql);
}

function transaction(callback) {
  const db = getDb();
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = callback({ query, get, run });
    db.exec('COMMIT');
    return result;
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
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
  asyncPgQuery
};
