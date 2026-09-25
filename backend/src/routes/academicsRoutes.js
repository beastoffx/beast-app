const express = require('express');
const { query, get, run, transaction } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');
const bcrypt = require('bcryptjs');

const router = express.Router();

// ==================== SESSIONS ====================
router.get('/sessions', authenticateToken, (req, res) => {
  const sessions = query('SELECT * FROM academic_sessions ORDER BY start_date DESC');
  res.json({ success: true, data: sessions });
});

router.post('/sessions', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { name, start_date, end_date, is_current } = req.body;
  if (!name || !start_date || !end_date) {
    return res.status(400).json({ success: false, error: 'Name, start_date, and end_date are required.' });
  }

  const id = 'sess-' + Date.now();
  if (is_current) {
    run('UPDATE academic_sessions SET is_current = 0');
  }

  run(
    'INSERT INTO academic_sessions (id, name, start_date, end_date, is_current) VALUES (?, ?, ?, ?, ?)',
    [id, name, start_date, end_date, is_current ? 1 : 0]
  );

  logAudit(req.user.id, 'CREATE_SESSION', 'academic_sessions', id, { name }, req);
  res.json({ success: true, message: 'Session created successfully.', id });
});

// ==================== CLASSES ====================
router.get('/classes', authenticateToken, (req, res) => {
  const classes = query('SELECT * FROM classes ORDER BY name ASC');
  res.json({ success: true, data: classes });
});

router.post('/classes', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { name, stream, description } = req.body;
  if (!name) {
    return res.status(400).json({ success: false, error: 'Class name is required.' });
  }

  const id = 'class-' + Date.now();
  run(
    'INSERT INTO classes (id, name, stream, description) VALUES (?, ?, ?, ?)',
    [id, name, stream || '', description || '']
  );

  logAudit(req.user.id, 'CREATE_CLASS', 'classes', id, { name, stream }, req);
  res.json({ success: true, message: 'Class created successfully.', id });
});

// ==================== BATCHES ====================
router.get('/batches', authenticateToken, (req, res) => {
  const batches = query(
    `SELECT b.*, c.name as class_name, c.stream as class_stream, s.name as session_name,
            (SELECT COUNT(*) FROM enrollments e WHERE e.batch_id = b.id AND e.status = 'active') as student_count
     FROM batches b
     JOIN classes c ON b.class_id = c.id
     JOIN academic_sessions s ON b.academic_session_id = s.id
     ORDER BY b.name ASC`
  );
  res.json({ success: true, data: batches });
});

router.post('/batches', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { name, class_id, academic_session_id, max_capacity } = req.body;
  if (!name || !class_id || !academic_session_id) {
    return res.status(400).json({ success: false, error: 'Name, class_id, and academic_session_id are required.' });
  }

  const id = 'batch-' + Date.now();
  run(
    'INSERT INTO batches (id, name, class_id, academic_session_id, max_capacity) VALUES (?, ?, ?, ?, ?)',
    [id, name, class_id, academic_session_id, max_capacity || 40]
  );

  logAudit(req.user.id, 'CREATE_BATCH', 'batches', id, { name, class_id }, req);
  res.json({ success: true, message: 'Batch created successfully.', id });
});

// ==================== SUBJECTS ====================
router.get('/subjects', authenticateToken, (req, res) => {
  const { class_id, batch_id } = req.query;
  let sql = `SELECT s.*, c.name as class_name FROM subjects s JOIN classes c ON s.class_id = c.id`;
  let params = [];

  if (class_id) {
    sql += ` WHERE s.class_id = ?`;
    params.push(class_id);
  } else if (batch_id) {
    sql += ` WHERE s.class_id = (SELECT class_id FROM batches WHERE id = ?)`;
    params.push(batch_id);
  }
  sql += ` ORDER BY s.name ASC`;

  const subjects = query(sql, params);
  res.json({ success: true, data: subjects });
});

router.post('/subjects', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { name, code, class_id, description } = req.body;
  if (!name || !code || !class_id) {
    return res.status(400).json({ success: false, error: 'Subject name, code, and class_id are required.' });
  }

  const id = 'sub-' + Date.now();
  run(
    'INSERT INTO subjects (id, name, code, class_id, description) VALUES (?, ?, ?, ?, ?)',
    [id, name, code, class_id, description || '']
  );

  logAudit(req.user.id, 'CREATE_SUBJECT', 'subjects', id, { name, code }, req);
  res.json({ success: true, message: 'Subject created successfully.', id });
});

// ==================== TEACHER ASSIGNMENTS ====================
router.get('/teacher-assignments', authenticateToken, (req, res) => {
  const { teacher_id, batch_id } = req.query;
  let sql = `
    SELECT ta.*, u.name as teacher_name, u.email as teacher_email,
           b.name as batch_name, s.name as subject_name, s.code as subject_code
    FROM teacher_assignments ta
    JOIN users u ON ta.teacher_id = u.id
    JOIN batches b ON ta.batch_id = b.id
    JOIN subjects s ON ta.subject_id = s.id
  `;
  const params = [];
  const clauses = [];

  if (teacher_id) {
    clauses.push('ta.teacher_id = ?');
    params.push(teacher_id);
  }
  if (batch_id) {
    clauses.push('ta.batch_id = ?');
    params.push(batch_id);
  }
  if (clauses.length > 0) {
    sql += ' WHERE ' + clauses.join(' AND ');
  }

  const assignments = query(sql, params);
  res.json({ success: true, data: assignments });
});

router.post('/teacher-assignments', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { teacher_id, batch_id, subject_id, academic_session_id } = req.body;
  if (!teacher_id || !batch_id || !subject_id || !academic_session_id) {
    return res.status(400).json({ success: false, error: 'All assignment fields are required.' });
  }

  const id = 'ta-' + Date.now();
  run(
    `INSERT OR REPLACE INTO teacher_assignments (id, teacher_id, batch_id, subject_id, academic_session_id)
     VALUES (?, ?, ?, ?, ?)`,
    [id, teacher_id, batch_id, subject_id, academic_session_id]
  );

  logAudit(req.user.id, 'ASSIGN_TEACHER', 'teacher_assignments', id, { teacher_id, batch_id, subject_id }, req);
  res.json({ success: true, message: 'Teacher assigned to batch successfully.', id });
});

// ==================== STUDENTS ENROLLMENT & MANAGEMENT ====================
router.get('/students', authenticateToken, authorizeRoles('admin', 'teacher'), (req, res) => {
  const { batch_id, class_id } = req.query;
  let sql = `
    SELECT u.id, u.name, u.email, u.phone, u.avatar_url, u.is_active,
           sp.student_id_number, sp.class_id, sp.batch_id, sp.academic_session_id, sp.emergency_contact,
           c.name as class_name, b.name as batch_name
    FROM users u
    JOIN student_profiles sp ON u.id = sp.user_id
    LEFT JOIN classes c ON sp.class_id = c.id
    LEFT JOIN batches b ON sp.batch_id = b.id
    WHERE u.role = 'student'
  `;
  const params = [];

  if (batch_id) {
    sql += ' AND sp.batch_id = ?';
    params.push(batch_id);
  }
  if (class_id) {
    sql += ' AND sp.class_id = ?';
    params.push(class_id);
  }

  sql += ' ORDER BY u.name ASC';
  const students = query(sql, params);
  res.json({ success: true, data: students });
});

// Admin creates student
router.post('/students', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { name, email, password, phone, student_id_number, class_id, batch_id, academic_session_id, emergency_contact } = req.body;

  if (!name || !email || !password || !student_id_number || !batch_id || !class_id || !academic_session_id) {
    return res.status(400).json({ success: false, error: 'All mandatory student details are required.' });
  }

  const existing = get('SELECT id FROM users WHERE email = ?', [email.trim().toLowerCase()]);
  if (existing) {
    return res.status(400).json({ success: false, error: 'User with this email already exists.' });
  }

  const userId = 'user-stu-' + Date.now();
  const profileId = 'stu-prof-' + Date.now();
  const enrollmentId = 'enr-' + Date.now();
  const passwordHash = bcrypt.hashSync(password, 10);

  transaction(() => {
    run(
      'INSERT INTO users (id, email, password_hash, role, name, phone) VALUES (?, ?, ?, ?, ?, ?)',
      [userId, email.trim().toLowerCase(), passwordHash, 'student', name, phone || null]
    );

    run(
      `INSERT INTO student_profiles (id, user_id, student_id_number, class_id, batch_id, academic_session_id, emergency_contact)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [profileId, userId, student_id_number, class_id, batch_id, academic_session_id, emergency_contact || null]
    );

    run(
      `INSERT INTO enrollments (id, student_id, batch_id, academic_session_id, status)
       VALUES (?, ?, ?, ?, 'active')`,
      [enrollmentId, userId, batch_id, academic_session_id]
    );
  });

  logAudit(req.user.id, 'CREATE_STUDENT', 'users', userId, { name, email, student_id_number, batch_id }, req);
  res.json({ success: true, message: 'Student registered and enrolled successfully.', id: userId });
});

// ==================== TEACHERS MANAGEMENT ====================
router.get('/teachers', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const teachers = query(
    `SELECT u.id, u.name, u.email, u.phone, u.avatar_url, u.is_active,
            tp.employee_code, tp.qualification, tp.bio, tp.contact_number, tp.joining_date
     FROM users u
     JOIN teacher_profiles tp ON u.id = tp.user_id
     WHERE u.role = 'teacher'
     ORDER BY u.name ASC`
  );
  res.json({ success: true, data: teachers });
});

router.post('/teachers', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { name, email, password, phone, employee_code, qualification, bio } = req.body;

  if (!name || !email || !password || !employee_code) {
    return res.status(400).json({ success: false, error: 'Name, email, password, and employee code are required.' });
  }

  const existing = get('SELECT id FROM users WHERE email = ?', [email.trim().toLowerCase()]);
  if (existing) {
    return res.status(400).json({ success: false, error: 'User with this email already exists.' });
  }

  const userId = 'user-tch-' + Date.now();
  const profileId = 'tch-prof-' + Date.now();
  const passwordHash = bcrypt.hashSync(password, 10);

  transaction(() => {
    run(
      'INSERT INTO users (id, email, password_hash, role, name, phone) VALUES (?, ?, ?, ?, ?, ?)',
      [userId, email.trim().toLowerCase(), passwordHash, 'teacher', name, phone || null]
    );

    run(
      `INSERT INTO teacher_profiles (id, user_id, employee_code, qualification, bio, contact_number)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [profileId, userId, employee_code, qualification || '', bio || '', phone || '']
    );
  });

  logAudit(req.user.id, 'CREATE_TEACHER', 'users', userId, { name, email, employee_code }, req);
  res.json({ success: true, message: 'Teacher registered successfully.', id: userId });
});

module.exports = router;
