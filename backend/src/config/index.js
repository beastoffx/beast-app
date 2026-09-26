require('dotenv').config();
const path = require('path');

const config = {
  port: parseInt(process.env.PORT || '5000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  jwtSecret: process.env.JWT_SECRET || 'beast_academy_super_secure_jwt_secret_key_2026_production',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  dbPath: process.env.DB_PATH || path.join(__dirname, '..', '..', 'data', 'beast_academy.db'),
  uploadDir: process.env.UPLOAD_DIR || path.join(__dirname, '..', 'uploads'),
  corsOrigins: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',').map(s => s.trim()) : [],
  maxFileSize: 25 * 1024 * 1024, // 25 MB
  allowedMimeTypes: [
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain'
  ],
  // Database configuration
  databaseUrl: process.env.DATABASE_URL || null,
  // Supabase Cloud Configuration
  supabaseUrl: process.env.SUPABASE_URL || null,
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || null,
  supabaseResourcesBucket: process.env.SUPABASE_RESOURCES_BUCKET || 'beast-resources',
  supabaseDoubtsBucket: process.env.SUPABASE_DOUBTS_BUCKET || 'beast-doubts',
  // Google OAuth Configuration
  googleClientIdWeb: process.env.GOOGLE_CLIENT_ID_WEB || null,
  googleClientIdAndroid: process.env.GOOGLE_CLIENT_ID_ANDROID || 'com.beastacademy.beast_academy',
  // OTP Provider Configuration
  otpProvider: process.env.OTP_PROVIDER || 'console',
  otpTtlMinutes: parseInt(process.env.OTP_TTL_MINUTES || '10', 10)
};

module.exports = config;
