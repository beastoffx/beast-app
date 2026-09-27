const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const config = require('./config');
const { initSchema, isUsingPostgres, getDbTargetDescription, getPgPool, getDb } = require('./db');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

// Route imports
const authRoutes = require('./routes/authRoutes');
const adminRoutes = require('./routes/adminRoutes');
const academicsRoutes = require('./routes/academicsRoutes');
const timetableRoutes = require('./routes/timetableRoutes');
const attendanceRoutes = require('./routes/attendanceRoutes');
const assignmentsRoutes = require('./routes/assignmentsRoutes');
const materialsRoutes = require('./routes/materialsRoutes');
const noticesRoutes = require('./routes/noticesRoutes');
const examsRoutes = require('./routes/examsRoutes');
const resultsRoutes = require('./routes/resultsRoutes');
const feesRoutes = require('./routes/feesRoutes');
const doubtsRoutes = require('./routes/doubtsRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const notificationsRoutes = require('./routes/notificationsRoutes');
const searchRoutes = require('./routes/searchRoutes');
const auditRoutes = require('./routes/auditRoutes');
const aiRoutes = require('./routes/aiRoutes');
const requestRoutes = require('./routes/requestRoutes');

function createApp() {
  const app = express();

  // Security headers & CORS
  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' }
  }));
  // Production-grade CORS policy supporting mobile apps and authorized web clients
  const allowedOrigins = config.corsOrigins || [];
  app.use(cors({
    origin: (origin, callback) => {
      // 1. Allow mobile apps and native non-browser clients (which do not send an Origin header)
      if (!origin) return callback(null, true);

      // 2. Allow local development origins (localhost, 127.0.0.1 on any port)
      if (/^https?:\/\/localhost(:\d+)?$/.test(origin) || /^https?:\/\/127\.0\.0\.1(:\d+)?$/.test(origin)) {
        return callback(null, true);
      }

      // 3. Allow official Vercel web deployments (*.vercel.app) and institutional domains
      if (origin.endsWith('.vercel.app') || origin === 'https://beastacademy.edu') {
        return callback(null, true);
      }

      // 4. Allow explicitly configured production origins from CORS_ORIGINS
      if (allowedOrigins.length > 0) {
        const isAllowed = allowedOrigins.some(allowed => {
          if (allowed === '*') return true;
          if (allowed.startsWith('*.')) {
            const domain = allowed.slice(2);
            return origin.endsWith(domain);
          }
          return origin === allowed;
        });
        if (isAllowed) return callback(null, true);
      }

      // Safe reject without throwing unhandled 500 error in Express pipeline
      return callback(null, false);
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    credentials: true
  }));

  // Body parsers
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Logging in non-test mode
  if (config.nodeEnv !== 'test') {
    app.use(morgan('dev'));
  }

  // Static uploads directory
  app.use('/uploads', express.static(config.uploadDir));

  // Health check
  app.get('/api/health', async (req, res) => {
    let dbStatus = 'CONNECTED';
    try {
      if (isUsingPostgres()) {
        const pool = getPgPool();
        await pool.query('SELECT 1');
      } else {
        const db = getDb();
        db.prepare('SELECT 1').get();
      }
    } catch (err) {
      dbStatus = `ERROR: ${err.message}`;
    }

    res.json({
      status: 'UP',
      app: 'B.E.A.S.T ACADEMY Production API',
      version: '1.0.0',
      database: {
        status: dbStatus,
        engine: isUsingPostgres() ? 'PostgreSQL' : 'SQLite',
        target: getDbTargetDescription()
      },
      timestamp: new Date().toISOString()
    });
  });

  // Mount API modules
  app.use('/api/auth', authRoutes);
  app.use('/api/admins', adminRoutes);
  app.use('/api/academics', academicsRoutes);
  app.use('/api/timetable', timetableRoutes);
  app.use('/api/attendance', attendanceRoutes);
  app.use('/api/assignments', assignmentsRoutes);
  app.use('/api/materials', materialsRoutes);
  app.use('/api/notices', noticesRoutes);
  app.use('/api/exams', examsRoutes);
  app.use('/api/results', resultsRoutes);
  app.use('/api/fees', feesRoutes);
  app.use('/api/doubts', doubtsRoutes);
  app.use('/api/dashboard', dashboardRoutes);
  app.use('/api/notifications', notificationsRoutes);
  app.use('/api/search', searchRoutes);
  app.use('/api/audit-logs', auditRoutes);
  app.use('/api/ai', aiRoutes);
  app.use('/api/requests', requestRoutes);

  // 404 & Global Error Handling
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

if (require.main === module) {
  (async () => {
    try {
      await initSchema();
      const app = createApp();
      const port = config.port;
      app.listen(port, () => {
        console.log(`====================================================`);
        console.log(`B.E.A.S.T ACADEMY Server running on port ${port}`);
        console.log(`Environment: ${config.nodeEnv}`);
        console.log(`Database: ${getDbTargetDescription()}`);
        console.log(`Engine: ${isUsingPostgres() ? 'PostgreSQL (Supabase)' : 'SQLite'}`);
        console.log(`Uploads: ${config.uploadDir}`);
        console.log(`Health: http://localhost:${port}/api/health`);
        console.log(`====================================================`);
      });
    } catch (err) {
      console.error('[FATAL] Failed to initialize server:', err);
      process.exit(1);
    }
  })();
}

module.exports = { createApp };
