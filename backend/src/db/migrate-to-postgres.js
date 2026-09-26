const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const config = require('../config');
const { getDb } = require('./index');

async function migrateToPostgres() {
  if (!config.databaseUrl) {
    console.error('[MIGRATE] ERROR: DATABASE_URL is not set in environment.');
    console.log('[MIGRATE] Please set DATABASE_URL in your .env file to point to your Supabase PostgreSQL database.');
    return { success: false, error: 'DATABASE_URL missing' };
  }

  console.log('[MIGRATE] Connecting to PostgreSQL database...');
  const pool = new Pool({
    connectionString: config.databaseUrl,
    ssl: (config.nodeEnv === 'production' || (config.databaseUrl && config.databaseUrl.includes('supabase'))) ? { rejectUnauthorized: false } : false
  });

  const client = await pool.connect();
  try {
    console.log('[MIGRATE] Applying PostgreSQL schema...');
    const schemaSql = fs.readFileSync(path.join(__dirname, 'migrations', '001_postgres_schema.sql'), 'utf8');
    await client.query(schemaSql);
    console.log('[MIGRATE] Schema applied successfully.');

    // Connect to SQLite
    const sqliteDb = getDb();

    // Tables in topological dependency order
    const tables = [
      'academic_sessions',
      'classes',
      'batches',
      'subjects',
      'users',
      'student_profiles',
      'teacher_profiles',
      'admin_profiles',
      'enrollments',
      'teacher_assignments',
      'timetables',
      'attendance',
      'notices',
      'assignments',
      'assignment_submissions',
      'study_materials',
      'exams',
      'exam_subjects',
      'results',
      'fee_records',
      'doubts',
      'doubt_responses',
      'notifications',
      'audit_logs',
      'phone_verifications'
    ];

    console.log('[MIGRATE] Migrating table rows from SQLite to PostgreSQL...');
    let totalMigrated = 0;

    for (const table of tables) {
      try {
        const rows = sqliteDb.prepare(`SELECT * FROM ${table}`).all();
        if (rows.length === 0) continue;

        console.log(`[MIGRATE] Table "${table}": found ${rows.length} rows.`);

        for (const row of rows) {
          const keys = Object.keys(row);
          const values = Object.values(row).map(val => {
            if (typeof val === 'boolean') return val;
            return val;
          });

          const cols = keys.join(', ');
          const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');

          const queryText = `
            INSERT INTO ${table} (${cols})
            VALUES (${placeholders})
            ON CONFLICT (id) DO NOTHING;
          `;

          await client.query(queryText, values);
          totalMigrated++;
        }
      } catch (err) {
        console.warn(`[MIGRATE] Note on table "${table}": ${err.message}`);
      }
    }

    console.log(`[MIGRATE] Migration complete! Successfully processed ${totalMigrated} rows.`);
    return { success: true, totalMigrated };
  } finally {
    client.release();
    await pool.end();
  }
}

if (require.main === module) {
  migrateToPostgres()
    .then(result => {
      if (result.success) {
        console.log('[MIGRATE] SUCCESS');
        process.exit(0);
      } else {
        console.error('[MIGRATE] FAILED:', result.error);
        process.exit(1);
      }
    })
    .catch(err => {
      console.error('[MIGRATE] FATAL:', err);
      process.exit(1);
    });
}

module.exports = { migrateToPostgres };
