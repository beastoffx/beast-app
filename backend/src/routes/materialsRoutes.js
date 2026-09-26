const express = require('express');
const { query, get, run } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');
const upload = require('../middleware/upload');
const { StorageService } = require('../services/storageService');

const router = express.Router();

// GET /api/materials - Filter by subject, chapter, class, batch
router.get('/', authenticateToken, async (req, res) => {
  const { subject_id, chapter, class_id, batch_id } = req.query;
  const user = req.user;

  let sql = `
    SELECT m.*, s.name as subject_name, s.code as subject_code,
           c.name as class_name, b.name as batch_name, u.name as teacher_name
    FROM study_materials m
    JOIN subjects s ON m.subject_id = s.id
    JOIN classes c ON m.class_id = c.id
    LEFT JOIN batches b ON m.batch_id = b.id
    JOIN users u ON m.teacher_id = u.id
    WHERE 1=1
  `;
  const params = [];

  // If student, restrict to their class/batch
  if (user.role === 'student') {
    sql += ` AND (m.batch_id IS NULL OR m.batch_id = (SELECT batch_id FROM student_profiles WHERE user_id = ?))`;
    params.push(user.id);
  }

  if (subject_id) {
    sql += ` AND m.subject_id = ?`;
    params.push(subject_id);
  }
  if (chapter) {
    sql += ` AND m.chapter LIKE ?`;
    params.push(`%${chapter}%`);
  }
  if (class_id) {
    sql += ` AND m.class_id = ?`;
    params.push(class_id);
  }
  if (batch_id) {
    sql += ` AND m.batch_id = ?`;
    params.push(batch_id);
  }

  sql += ` ORDER BY m.created_at DESC`;

  const materials = await query(sql, params);
  res.json({ success: true, data: materials });
});

// POST /api/materials - Teacher or Admin uploads material
router.post('/', authenticateToken, authorizeRoles('teacher', 'admin'), upload.single('file'), async (req, res) => {
  const { title, description, subject_id, class_id, batch_id, chapter, file_url } = req.body;

  if (!title || !subject_id || !class_id) {
    return res.status(400).json({ success: false, error: 'Title, subject_id, and class_id are required.' });
  }

  let finalFileUrl = file_url;
  let fileType = 'application/pdf';
  let fileSize = 0;

  if (req.file) {
    finalFileUrl = `/uploads/materials/${req.file.filename}`;
    fileType = req.file.mimetype;
    fileSize = req.file.size;
  } else if (!finalFileUrl) {
    return res.status(400).json({ success: false, error: 'Either an uploaded file or file_url is required.' });
  }

  const id = 'mat-' + Date.now();
  await run(
    `INSERT INTO study_materials (id, title, description, file_url, file_type, file_size, subject_id, batch_id, class_id, chapter, teacher_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      title,
      description || '',
      finalFileUrl,
      fileType,
      fileSize,
      subject_id,
      batch_id || null,
      class_id,
      chapter || 'General',
      req.user.id
    ]
  );

  await logAudit(req.user.id, 'UPLOAD_STUDY_MATERIAL', 'study_materials', id, { title, subject_id, class_id }, req);
  res.json({ success: true, message: 'Study material uploaded successfully.', id });
});

// DELETE /api/materials/:id - Teacher or Admin deletes material
router.delete('/:id', authenticateToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  const { id } = req.params;
  const material = await get('SELECT * FROM study_materials WHERE id = ?', [id]);
  if (!material) {
    return res.status(404).json({ success: false, error: 'Material not found.' });
  }

  // If teacher, only allow deleting their own material
  if (req.user.role === 'teacher' && material.teacher_id !== req.user.id) {
    return res.status(403).json({ success: false, error: 'You are not authorized to delete another teacher\'s material.' });
  }

  await run('DELETE FROM study_materials WHERE id = ?', [id]);
  await logAudit(req.user.id, 'DELETE_STUDY_MATERIAL', 'study_materials', id, {}, req);
  res.json({ success: true, message: 'Material deleted successfully.' });
});

// GET /api/materials/:id/download-url - Authorized private file access
router.get('/:id/download-url', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const material = await get('SELECT * FROM study_materials WHERE id = ?', [id]);
  if (!material) {
    return res.status(404).json({ success: false, error: 'Material not found.' });
  }

  // Authorization checks
  if (req.user.role === 'student') {
    // 1. Subscription validity
    if (req.user.access_end_date && new Date(req.user.access_end_date) < new Date()) {
      return res.status(403).json({
        success: false,
        error: 'Your academic subscription has expired. Please contact administration.'
      });
    }

    // 2. Resource tier permission
    if (req.user.resource_permissions && req.user.resource_permissions.materials === false) {
      return res.status(403).json({
        success: false,
        error: 'Study material access is not enabled for your current student tier.'
      });
    }

    // 3. Academic scope verification (must belong to this class or batch)
    const studentProfile = await get('SELECT class_id, batch_id FROM student_profiles WHERE user_id = ?', [req.user.id]);
    if (studentProfile) {
      if (material.batch_id && studentProfile.batch_id && material.batch_id !== studentProfile.batch_id) {
        return res.status(403).json({
          success: false,
          error: 'You do not have permission to access resources outside your assigned batch.'
        });
      }
    }
  }

  const downloadResult = await StorageService.getAuthorizedDownloadUrl({
    bucket: 'beast-resources',
    key: material.file_url,
    expiresInSeconds: 3600
  });

  res.json({
    success: true,
    downloadUrl: downloadResult.url,
    storageProvider: downloadResult.storageProvider
  });
});

module.exports = router;
