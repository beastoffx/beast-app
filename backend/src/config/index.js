require('dotenv').config();
const path = require('path');

const config = {
  port: parseInt(process.env.PORT || '5000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  jwtSecret: process.env.JWT_SECRET || 'beast_academy_super_secure_jwt_secret_key_2026_production',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  dbPath: process.env.DB_PATH || path.join(__dirname, '..', '..', 'data', 'beast_academy.db'),
  uploadDir: process.env.UPLOAD_DIR || path.join(__dirname, '..', 'uploads'),
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
  ]
};

module.exports = config;
