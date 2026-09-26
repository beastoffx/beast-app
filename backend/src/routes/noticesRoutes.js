const express = require('express');
const { query, get, run } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');

const router = express.Router();

// GET /api/notices - Scoped to user role and enrolled batch
router.get('/', authenticateToken, async (req, res) => {
  const user = req.user;
  let sql = `
    SELECT n.*, u.name as author_name, u.role as author_role
    FROM notices n
    JOIN users u ON n.author_id = u.id
    WHERE 1=1
  `;
  const params = [];

  if (user.role === 'student') {
    // Student sees: target_type = 'all', or target_type = 'batch' matching student batch, or target_type = 'class' matching student class
    sql += `
      AND (
        n.target_type = 'all'
        OR (n.target_type = 'batch' AND n.target_id = (SELECT batch_id FROM student_profiles WHERE user_id = ?))
        OR (n.target_type = 'class' AND n.target_id = (SELECT class_id FROM student_profiles WHERE user_id = ?))
      )
    `;
    params.push(user.id, user.id);
  } else if (user.role === 'teacher') {
    // Teacher sees 'all' and notices targeting their assigned batches
    sql += `
      AND (
        n.target_type = 'all'
        OR n.target_type = 'role'
        OR n.author_id = ?
        OR (n.target_type = 'batch' AND n.target_id IN (SELECT batch_id FROM teacher_assignments WHERE teacher_id = ?))
      )
    `;
    params.push(user.id, user.id);
  }

  sql += ` ORDER BY n.is_pinned DESC, n.publish_date DESC, n.created_at DESC`;

  const notices = await query(sql, params);
  res.json({ success: true, data: notices });
});

// POST /api/notices - Admin or authorized teacher creates notice
router.post('/', authenticateToken, authorizeRoles('admin', 'teacher'), async (req, res) => {
  const { title, description, category, priority, target_type, target_id, attachment_url, is_pinned } = req.body;

  if (!title || !description || !category) {
    return res.status(400).json({ success: false, error: 'Title, description, and category are required.' });
  }

  const validCategories = ['academic', 'exam', 'class', 'holiday', 'general', 'urgent'];
  if (!validCategories.includes(category)) {
    return res.status(400).json({ success: false, error: `Invalid category. Must be one of: ${validCategories.join(', ')}` });
  }

  const id = 'notice-' + Date.now();
  const publishDate = new Date().toISOString().split('T')[0];

  await run(
    `INSERT INTO notices (id, title, description, category, priority, target_type, target_id, author_id, publish_date, is_pinned)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      title,
      description,
      category,
      priority || 'medium',
      target_type || 'all',
      target_id || null,
      req.user.id,
      publishDate,
      is_pinned ? 1 : 0
    ]
  );

  await logAudit(req.user.id, 'PUBLISH_NOTICE', 'notices', id, { title, category, priority }, req);
  res.json({ success: true, message: 'Notice published successfully.', id });
});

// DELETE /api/notices/:id
router.delete('/:id', authenticateToken, authorizeRoles('admin', 'teacher'), async (req, res) => {
  const { id } = req.params;
  const notice = await get('SELECT * FROM notices WHERE id = ?', [id]);
  if (!notice) {
    return res.status(404).json({ success: false, error: 'Notice not found.' });
  }

  if (req.user.role === 'teacher' && notice.author_id !== req.user.id) {
    return res.status(403).json({ success: false, error: 'You are not authorized to delete another author\'s notice.' });
  }

  await run('DELETE FROM notices WHERE id = ?', [id]);
  await logAudit(req.user.id, 'DELETE_NOTICE', 'notices', id, {}, req);
  res.json({ success: true, message: 'Notice deleted successfully.' });
});

module.exports = router;
