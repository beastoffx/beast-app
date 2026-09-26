const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const config = require('./config');
const { initSchema } = require('./db');
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

function createApp() {
  const app = express();

  // Security headers & CORS
  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' }
  }));
  // Production-grade CORS policy
  const allowedOrigins = config.corsOrigins || [];
  app.use(cors({
    origin: (origin, callback) => {
      // 1. Allow mobile apps and native non-browser clients (which do not send an Origin header)
      if (!origin) return callback(null, true);

      // 2. Allow local development origins in development/test environments
      if (config.nodeEnv !== 'production') {
        if (/^https?:\/\/localhost(:\d+)?$/.test(origin) || /^https?:\/\/127\.0\.0\.1(:\d+)?$/.test(origin)) {
          return callback(null, true);
        }
      }

      // 3. Allow explicitly configured production origins
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
        return callback(new Error(`Origin ${origin} is not allowed by CORS policy.`));
      }

      // Default in non-production with no origins configured: allow
      if (config.nodeEnv !== 'production') {
        return callback(null, true);
      }

      // Production default with no origins specified: reject unknown browser origins
      return callback(new Error(`Origin ${origin} is not allowed by CORS policy.`));
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
  app.get('/api/health', (req, res) => {
    res.json({
      status: 'UP',
      app: 'B.E.A.S.T ACADEMY Production API',
      version: '1.0.0',
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

  // 404 & Global Error Handling
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

if (require.main === module) {
  initSchema();
  const app = createApp();
  const port = config.port;
  app.listen(port, () => {
    console.log(`====================================================`);
    console.log(`B.E.A.S.T ACADEMY Server running on port ${port}`);
    console.log(`Environment: ${config.nodeEnv}`);
    console.log(`Database: ${config.dbPath}`);
    console.log(`Uploads: ${config.uploadDir}`);
    console.log(`Health: http://localhost:${port}/api/health`);
    console.log(`====================================================`);
  });
}

module.exports = { createApp };
