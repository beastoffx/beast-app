const express = require('express');
const { query, get, run, transaction } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');

const router = express.Router();

// GET /api/exams - List exams
router.get('/', authenticateToken, (req, res) => {
  const user = req.user;
  let sql = `
    SELECT e.*, b.name as batch_name, s.name as session_name
    FROM exams e
    LEFT JOIN batches b ON e.batch_id = b.id
    JOIN academic_sessions s ON e.academic_session_id = s.id
    WHERE 1=1
  `;
  const params = [];

  if (user.role === 'student') {
    sql += ` AND (e.batch_id IS NULL OR e.batch_id = (SELECT batch_id FROM student_profiles WHERE user_id = ?))`;
    params.push(user.id);
  }

  sql += ` ORDER BY e.start_date DESC`;
  const exams = query(sql, params);

  // Attach exam subjects to each exam
  const fullExams = exams.map(exam => {
    const subjects = query(
      `SELECT es.*, s.name as subject_name, s.code as subject_code
       FROM exam_subjects es
       JOIN subjects s ON es.subject_id = s.id
       WHERE es.exam_id = ?
       ORDER BY es.exam_date ASC, es.start_time ASC`,
      [exam.id]
    );
    return { ...exam, subjects };
  });

  res.json({ success: true, data: fullExams });
});

// POST /api/exams - Admin or Teacher creates exam with subject schedule
router.post('/', authenticateToken, authorizeRoles('admin', 'teacher'), (req, res) => {
  const { title, academic_session_id, batch_id, exam_type, start_date, end_date, instructions, subjects } = req.body;

  if (!title || !academic_session_id || !start_date || !end_date) {
    return res.status(400).json({ success: false, error: 'Title, academic session, start date, and end date are required.' });
  }

  const examId = 'exam-' + Date.now();

  transaction(() => {
    run(
      `INSERT INTO exams (id, title, academic_session_id, batch_id, exam_type, start_date, end_date, instructions)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [examId, title, academic_session_id, batch_id || null, exam_type || 'offline', start_date, end_date, instructions || '']
    );

    if (Array.isArray(subjects) && subjects.length > 0) {
      subjects.forEach(sub => {
        const esId = 'es-' + Date.now() + '-' + Math.random().toString(36).substring(2, 6);
        run(
          `INSERT INTO exam_subjects (id, exam_id, subject_id, exam_date, start_time, duration_minutes, max_marks, passing_marks)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            esId,
            examId,
            sub.subject_id,
            sub.exam_date || start_date,
            sub.start_time || '09:00',
            sub.duration_minutes || 180,
            sub.max_marks || 100,
            sub.passing_marks || 35
          ]
        );
      });
    }
  });

  logAudit(req.user.id, 'CREATE_EXAM', 'exams', examId, { title, batch_id }, req);
  res.json({ success: true, message: 'Examination created successfully.', id: examId });
});

// POST /api/exams/:id/subjects - Add subject slot to exam
router.post('/:id/subjects', authenticateToken, authorizeRoles('admin', 'teacher'), (req, res) => {
  const examId = req.params.id;
  const { subject_id, exam_date, start_time, duration_minutes, max_marks, passing_marks } = req.body;

  if (!subject_id || !exam_date || !start_time) {
    return res.status(400).json({ success: false, error: 'Subject, exam date, and start time are required.' });
  }

  const esId = 'es-' + Date.now();
  run(
    `INSERT INTO exam_subjects (id, exam_id, subject_id, exam_date, start_time, duration_minutes, max_marks, passing_marks)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [esId, examId, subject_id, exam_date, start_time, duration_minutes || 180, max_marks || 100, passing_marks || 35]
  );

  res.json({ success: true, message: 'Subject added to examination schedule.', id: esId });
});

module.exports = router;
