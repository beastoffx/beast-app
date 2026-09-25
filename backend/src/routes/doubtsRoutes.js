const express = require('express');
const { query, get, run, transaction } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');
const upload = require('../middleware/upload');

const router = express.Router();

// GET /api/doubts/my - Student views their doubts
router.get('/my', authenticateToken, authorizeRoles('student'), (req, res) => {
  const { status } = req.query;
  let sql = `
    SELECT d.*, s.name as subject_name, s.code as subject_code,
           (SELECT COUNT(*) FROM doubt_responses dr WHERE dr.doubt_id = d.id) as response_count
    FROM doubts d
    JOIN subjects s ON d.subject_id = s.id
    WHERE d.student_id = ?
  `;
  const params = [req.user.id];

  if (status) {
    sql += ' AND d.status = ?';
    params.push(status);
  }

  sql += ' ORDER BY d.created_at DESC';
  const doubts = query(sql, params);

  // Group into open vs resolved
  const openDoubts = doubts.filter(d => d.status !== 'resolved');
  const resolvedDoubts = doubts.filter(d => d.status === 'resolved');

  res.json({
    success: true,
    data: {
      all: doubts,
      open: openDoubts,
      resolved: resolvedDoubts
    }
  });
});

// GET /api/doubts/assigned - Teacher views doubts for their subjects/batches
router.get('/assigned', authenticateToken, authorizeRoles('teacher', 'admin'), (req, res) => {
  let sql = '';
  let params = [];

  if (req.user.role === 'teacher') {
    sql = `
      SELECT d.*, s.name as subject_name, s.code as subject_code,
             u.name as student_name, b.name as batch_name,
             (SELECT COUNT(*) FROM doubt_responses dr WHERE dr.doubt_id = d.id) as response_count
      FROM doubts d
      JOIN subjects s ON d.subject_id = s.id
      JOIN users u ON d.student_id = u.id
      LEFT JOIN batches b ON d.batch_id = b.id
      WHERE d.subject_id IN (SELECT subject_id FROM teacher_assignments WHERE teacher_id = ?)
      ORDER BY CASE WHEN d.status = 'open' THEN 1 WHEN d.status = 'seen' THEN 2 WHEN d.status = 'in_discussion' THEN 3 ELSE 4 END,
               d.created_at DESC
    `;
    params = [req.user.id];
  } else {
    // Admin sees all doubts
    sql = `
      SELECT d.*, s.name as subject_name, s.code as subject_code,
             u.name as student_name, b.name as batch_name,
             (SELECT COUNT(*) FROM doubt_responses dr WHERE dr.doubt_id = d.id) as response_count
      FROM doubts d
      JOIN subjects s ON d.subject_id = s.id
      JOIN users u ON d.student_id = u.id
      LEFT JOIN batches b ON d.batch_id = b.id
      ORDER BY d.created_at DESC
    `;
  }

  const doubts = query(sql, params);
  res.json({ success: true, data: doubts });
});

// GET /api/doubts/:id - View single doubt with complete discussion thread
router.get('/:id', authenticateToken, (req, res) => {
  const { id } = req.params;

  const doubt = get(
    `SELECT d.*, s.name as subject_name, s.code as subject_code,
            u.name as student_name, u.email as student_email, b.name as batch_name
     FROM doubts d
     JOIN subjects s ON d.subject_id = s.id
     JOIN users u ON d.student_id = u.id
     LEFT JOIN batches b ON d.batch_id = b.id
     WHERE d.id = ?`,
    [id]
  );

  if (!doubt) {
    return res.status(404).json({ success: false, error: 'Doubt not found.' });
  }

  // Permission check: student can only view their own; teachers can only view if authorized
  if (req.user.role === 'student' && doubt.student_id !== req.user.id) {
    return res.status(403).json({ success: false, error: 'Forbidden. You cannot view another student\'s doubts.' });
  }

  // If teacher opens an 'open' doubt, mark status as 'seen'
  if (req.user.role === 'teacher' && doubt.status === 'open') {
    run(`UPDATE doubts SET status = 'seen', updated_at = datetime('now') WHERE id = ?`, [id]);
    doubt.status = 'seen';
  }

  // Fetch all discussion responses
  const responses = query(
    `SELECT dr.*, u.name as author_name, u.role as author_role, u.avatar_url
     FROM doubt_responses dr
     JOIN users u ON dr.author_id = u.id
     WHERE dr.doubt_id = ?
     ORDER BY dr.created_at ASC`,
    [id]
  );

  res.json({
    success: true,
    data: {
      doubt,
      responses
    }
  });
});

// POST /api/doubts - Student creates a doubt (Capture photo/gallery/text)
router.post('/', authenticateToken, authorizeRoles('student'), upload.single('image'), (req, res) => {
  const { subject_id, title, topic, note, priority } = req.body;
  const studentId = req.user.id;

  if (!subject_id || !title || !note) {
    return res.status(400).json({ success: false, error: 'Subject, title, and detailed note are required.' });
  }

  // Get student's enrolled batch
  const profile = get('SELECT batch_id FROM student_profiles WHERE user_id = ?', [studentId]);
  const batchId = profile ? profile.batch_id : null;

  const imageUrl = req.file ? `/uploads/doubts/${req.file.filename}` : (req.body.image_url || null);
  const doubtId = 'doubt-' + Date.now();

  run(
    `INSERT INTO doubts (id, student_id, subject_id, batch_id, title, topic, note, image_url, status, priority)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'open', ?)`,
    [doubtId, studentId, subject_id, batchId, title, topic || '', note, imageUrl, priority || 'normal']
  );

  logAudit(studentId, 'CREATE_DOUBT', 'doubts', doubtId, { subject_id, title }, req);
  res.json({ success: true, message: 'Doubt recorded and shared with your faculty.', id: doubtId });
});

// POST /api/doubts/:id/respond - Teacher or Student adds a response
router.post('/:id/respond', authenticateToken, upload.single('attachment'), (req, res) => {
  const { id } = req.params;
  const { message } = req.body;

  if (!message || message.trim().length === 0) {
    return res.status(400).json({ success: false, error: 'Message cannot be empty.' });
  }

  const doubt = get('SELECT * FROM doubts WHERE id = ?', [id]);
  if (!doubt) {
    return res.status(404).json({ success: false, error: 'Doubt not found.' });
  }

  const attachmentUrl = req.file ? `/uploads/doubts/${req.file.filename}` : (req.body.attachment_url || null);
  const respId = 'dr-' + Date.now();

  transaction(() => {
    run(
      `INSERT INTO doubt_responses (id, doubt_id, author_id, role, message, attachment_url)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [respId, id, req.user.id, req.user.role, message, attachmentUrl]
    );

    // Update doubt status
    if (req.user.role === 'teacher') {
      run(`UPDATE doubts SET status = 'answered', updated_at = datetime('now') WHERE id = ?`, [id]);

      // Create notification for student
      const notifId = 'notif-' + Date.now();
      run(
        `INSERT INTO notifications (id, user_id, title, message, type, reference_id)
         VALUES (?, ?, ?, ?, 'doubt', ?)`,
        [
          notifId,
          doubt.student_id,
          'Teacher Replied to Your Doubt',
          `${req.user.name} responded to your doubt: "${doubt.title.substring(0, 40)}..."`,
          id
        ]
      );
    } else if (req.user.role === 'student' && doubt.status === 'answered') {
      run(`UPDATE doubts SET status = 'in_discussion', updated_at = datetime('now') WHERE id = ?`, [id]);
    }
  });

  logAudit(req.user.id, 'RESPOND_TO_DOUBT', 'doubts', id, {}, req);
  res.json({ success: true, message: 'Response added to discussion thread.', id: respId });
});

// PUT /api/doubts/:id/resolve - Student marks doubt resolved or still unclear
router.put('/:id/resolve', authenticateToken, authorizeRoles('student'), (req, res) => {
  const { id } = req.params;
  const { is_resolved } = req.body;

  const doubt = get('SELECT * FROM doubts WHERE id = ? AND student_id = ?', [id, req.user.id]);
  if (!doubt) {
    return res.status(404).json({ success: false, error: 'Doubt not found or not owned by you.' });
  }

  const newStatus = is_resolved ? 'resolved' : 'in_discussion';
  run(`UPDATE doubts SET status = ?, updated_at = datetime('now') WHERE id = ?`, [newStatus, id]);

  logAudit(req.user.id, 'RESOLVE_DOUBT', 'doubts', id, { newStatus }, req);
  res.json({
    success: true,
    message: is_resolved ? 'Doubt marked as resolved! Great job.' : 'Doubt marked as still unclear. Discussion reopened.'
  });
});

module.exports = router;
