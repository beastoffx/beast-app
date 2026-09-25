const multer = require('multer');
const path = require('path');
const fs = require('fs');
const config = require('../config');

// Ensure upload subdirectories exist
const uploadDirs = ['materials', 'submissions', 'doubts', 'avatars'];
uploadDirs.forEach((dir) => {
  const fullPath = path.join(config.uploadDir, dir);
  if (!fs.existsSync(fullPath)) {
    fs.mkdirSync(fullPath, { recursive: true });
  }
});

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    let subfolder = 'materials';
    if (req.originalUrl.includes('assignment')) {
      subfolder = 'submissions';
    } else if (req.originalUrl.includes('doubt')) {
      subfolder = 'doubts';
    } else if (req.originalUrl.includes('avatar')) {
      subfolder = 'avatars';
    }
    cb(null, path.join(config.uploadDir, subfolder));
  },
  filename: (req, file, cb) => {
    // Generate safe, unguessable file names
    const ext = path.extname(file.originalname).toLowerCase();
    const cleanExt = ['.pdf', '.png', '.jpg', '.jpeg', '.webp', '.docx', '.txt'].includes(ext) ? ext : '.bin';
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, `${uniqueSuffix}${cleanExt}`);
  }
});

const fileFilter = (req, file, cb) => {
  if (config.allowedMimeTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`Invalid file type (${file.mimetype}). Allowed types: PDF, PNG, JPEG, WEBP, DOCX, TXT.`));
  }
};

const upload = multer({
  storage,
  limits: {
    fileSize: config.maxFileSize // 25 MB
  },
  fileFilter
});

module.exports = upload;
