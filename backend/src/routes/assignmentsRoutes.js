const express = require('express');
const { query, get, run } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');
const upload = require('../middleware/upload');

const router = express.Router();

// GET /api/assignments/my - Student or Teacher assignments
router.get('/my', authenticateToken, (req, res) => {
  const user = req.user;

  if (user.role === 'student') {
    // Student sees assignments for their enrolled batch with submission status
    const assignments = query(
      `SELECT a.*, s.name as subject_name, s.code as subject_code,
              u.name as teacher_name,
              sub.id as submission_id, sub.status as submission_status,
              sub.submitted_at, sub.marks as marks_obtained, sub.feedback, sub.file_url as submission_file_url
       FROM assignments a
       JOIN subjects s ON a.subject_id = s.id
       JOIN users u ON a.teacher_id = u.id
       LEFT JOIN assignment_submissions sub ON (a.id = sub.assignment_id AND sub.student_id = ?)
       WHERE a.batch_id = (SELECT batch_id FROM student_profiles WHERE user_id = ?)
       ORDER BY a.deadline ASC`,
      [user.id, user.id]
    );

    return res.json({ success: true, data: assignments });
  }

  if (user.role === 'teacher') {
    // Teacher sees assignments they created with submission statistics
    const assignments = query(
      `SELECT a.*, s.name as subject_name, s.code as subject_code, b.name as batch_name,
              (SELECT COUNT(*) FROM assignment_submissions WHERE assignment_id = a.id) as total_submissions,
              (SELECT COUNT(*) FROM assignment_submissions WHERE assignment_id = a.id AND status = 'reviewed') as reviewed_submissions,
              (SELECT COUNT(*) FROM enrollments WHERE batch_id = a.batch_id AND status = 'active') as total_students
       FROM assignments a
       JOIN subjects s ON a.subject_id = s.id
       JOIN batches b ON a.batch_id = b.id
       WHERE a.teacher_id = ?
       ORDER BY a.created_at DESC`,
      [user.id]
    );

    return res.json({ success: true, data: assignments });
  }

  // Admin sees all assignments
  const assignments = query(
    `SELECT a.*, s.name as subject_name, b.name as batch_name, u.name as teacher_name,
            (SELECT COUNT(*) FROM assignment_submissions WHERE assignment_id = a.id) as total_submissions
     FROM assignments a
     JOIN subjects s ON a.subject_id = s.id
     JOIN batches b ON a.batch_id = b.id
     JOIN users u ON a.teacher_id = u.id
     ORDER BY a.created_at DESC`
  );
  res.json({ success: true, data: assignments });
});

// POST /api/assignments - Teacher or Admin creates an assignment
router.post('/', authenticateToken, authorizeRoles('teacher', 'admin'), upload.single('attachment'), (req, res) => {
  const { title, subject_id, batch_id, description, deadline, max_marks, instructions } = req.body;

  if (!title || !subject_id || !batch_id || !deadline) {
    return res.status(400).json({ success: false, error: 'Title, subject_id, batch_id, and deadline are required.' });
  }

  const id = 'assign-' + Date.now();
  const attachmentUrl = req.file ? `/uploads/submissions/${req.file.filename}` : (req.body.attachment_url || null);

  run(
    `INSERT INTO assignments (id, title, subject_id, batch_id, teacher_id, description, deadline, max_marks, attachment_url, instructions)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      title,
      subject_id,
      batch_id,
      req.user.id,
      description || '',
      deadline,
      max_marks || 100,
      attachmentUrl,
      instructions || ''
    ]
  );

  logAudit(req.user.id, 'CREATE_ASSIGNMENT', 'assignments', id, { title, batch_id, subject_id }, req);
  res.json({ success: true, message: 'Assignment created successfully.', id });
});

// POST /api/assignments/:id/submit - Student submits assignment
router.post('/:id/submit', authenticateToken, authorizeRoles('student'), upload.single('file'), (req, res) => {
  const assignmentId = req.params.id;
  const studentId = req.user.id;
  const { notes } = req.body;

  const assignment = get('SELECT * FROM assignments WHERE id = ?', [assignmentId]);
  if (!assignment) {
    return res.status(404).json({ success: false, error: 'Assignment not found.' });
  }

  // Check if late
  const now = new Date();
  const deadline = new Date(assignment.deadline);
  const status = now > deadline ? 'late' : 'submitted';

  const fileUrl = req.file ? `/uploads/submissions/${req.file.filename}` : (req.body.file_url || null);

  const existing = get(
    'SELECT id, status FROM assignment_submissions WHERE assignment_id = ? AND student_id = ?',
    [assignmentId, studentId]
  );

  if (existing) {
    if (existing.status === 'reviewed') {
      return res.status(400).json({ success: false, error: 'Assignment has already been reviewed and graded. Cannot resubmit.' });
    }
    run(
      `UPDATE assignment_submissions
       SET file_url = COALESCE(?, file_url), notes = ?, submitted_at = datetime('now'), status = ?
       WHERE id = ?`,
      [fileUrl, notes || '', status, existing.id]
    );
  } else {
    const subId = 'sub-' + Date.now();
    run(
      `INSERT INTO assignment_submissions (id, assignment_id, student_id, file_url, notes, status)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [subId, assignmentId, studentId, fileUrl, notes || '', status]
    );
  }

  logAudit(studentId, 'SUBMIT_ASSIGNMENT', 'assignment_submissions', assignmentId, { status }, req);
  res.json({ success: true, message: 'Assignment submitted successfully.' });
});

// GET /api/assignments/:id/submissions - Teacher views all submissions for an assignment
router.get('/:id/submissions', authenticateToken, authorizeRoles('teacher', 'admin'), (req, res) => {
  const assignmentId = req.params.id;

  const submissions = query(
    `SELECT sub.*, u.name as student_name, u.email as student_email, sp.student_id_number
     FROM assignment_submissions sub
     JOIN users u ON sub.student_id = u.id
     JOIN student_profiles sp ON u.id = sp.user_id
     WHERE sub.assignment_id = ?
     ORDER BY sub.submitted_at DESC`,
    [assignmentId]
  );

  res.json({ success: true, data: submissions });
});

// PUT /api/assignments/submissions/:submissionId/grade - Teacher grades submission
router.put('/submissions/:submissionId/grade', authenticateToken, authorizeRoles('teacher', 'admin'), (req, res) => {
  const { submissionId } = req.params;
  const { marks, feedback } = req.body;

  if (marks === undefined || marks === null) {
    return res.status(400).json({ success: false, error: 'Marks are required for grading.' });
  }

  run(
    `UPDATE assignment_submissions
     SET marks = ?, feedback = ?, status = 'reviewed', reviewed_by = ?, reviewed_at = datetime('now')
     WHERE id = ?`,
    [marks, feedback || '', req.user.id, submissionId]
  );

  logAudit(req.user.id, 'GRADE_ASSIGNMENT_SUBMISSION', 'assignment_submissions', submissionId, { marks }, req);
  res.json({ success: true, message: 'Submission graded successfully.' });
});

module.exports = router;
