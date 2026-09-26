const express = require('express');
const { query, get, run, transaction } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');
const bcrypt = require('bcryptjs');

const router = express.Router();

// ==================== SESSIONS ====================
router.get('/sessions', authenticateToken, async (req, res) => {
  const sessions = await query('SELECT * FROM academic_sessions ORDER BY start_date DESC');
  res.json({ success: true, data: sessions });
});

router.post('/sessions', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { name, start_date, end_date, is_current } = req.body;
  if (!name || !start_date || !end_date) {
    return res.status(400).json({ success: false, error: 'Name, start_date, and end_date are required.' });
  }

  const id = 'sess-' + Date.now();
  if (is_current) {
    await run('UPDATE academic_sessions SET is_current = 0');
  }

  await run(
    'INSERT INTO academic_sessions (id, name, start_date, end_date, is_current) VALUES (?, ?, ?, ?, ?)',
    [id, name, start_date, end_date, is_current ? 1 : 0]
  );

  await logAudit(req.user.id, 'CREATE_SESSION', 'academic_sessions', id, { name }, req);
  res.json({ success: true, message: 'Session created successfully.', id });
});

// ==================== CLASSES ====================
router.get('/classes', authenticateToken, async (req, res) => {
  const classes = await query('SELECT * FROM classes ORDER BY name ASC');
  res.json({ success: true, data: classes });
});

router.post('/classes', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { name, stream, description } = req.body;
  if (!name) {
    return res.status(400).json({ success: false, error: 'Class name is required.' });
  }

  const id = 'class-' + Date.now();
  await run(
    'INSERT INTO classes (id, name, stream, description) VALUES (?, ?, ?, ?)',
    [id, name, stream || '', description || '']
  );

  await logAudit(req.user.id, 'CREATE_CLASS', 'classes', id, { name, stream }, req);
  res.json({ success: true, message: 'Class created successfully.', id });
});

// ==================== BATCHES ====================
router.get('/batches', authenticateToken, async (req, res) => {
  const batches = await query(
    `SELECT b.*, c.name as class_name, c.stream as class_stream, s.name as session_name,
            (SELECT COUNT(*) FROM enrollments e WHERE e.batch_id = b.id AND e.status = 'active') as student_count
     FROM batches b
     JOIN classes c ON b.class_id = c.id
     JOIN academic_sessions s ON b.academic_session_id = s.id
     ORDER BY b.name ASC`
  );
  res.json({ success: true, data: batches });
});

router.post('/batches', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { name, class_id, academic_session_id, max_capacity } = req.body;
  if (!name || !class_id || !academic_session_id) {
    return res.status(400).json({ success: false, error: 'Name, class_id, and academic_session_id are required.' });
  }

  const id = 'batch-' + Date.now();
  await run(
    'INSERT INTO batches (id, name, class_id, academic_session_id, max_capacity) VALUES (?, ?, ?, ?, ?)',
    [id, name, class_id, academic_session_id, max_capacity || 40]
  );

  await logAudit(req.user.id, 'CREATE_BATCH', 'batches', id, { name, class_id }, req);
  res.json({ success: true, message: 'Batch created successfully.', id });
});

// ==================== SUBJECTS ====================
router.get('/subjects', authenticateToken, async (req, res) => {
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

  const subjects = await query(sql, params);
  res.json({ success: true, data: subjects });
});

router.post('/subjects', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { name, code, class_id, description } = req.body;
  if (!name || !code || !class_id) {
    return res.status(400).json({ success: false, error: 'Subject name, code, and class_id are required.' });
  }

  const id = 'sub-' + Date.now();
  await run(
    'INSERT INTO subjects (id, name, code, class_id, description) VALUES (?, ?, ?, ?, ?)',
    [id, name, code, class_id, description || '']
  );

  await logAudit(req.user.id, 'CREATE_SUBJECT', 'subjects', id, { name, code }, req);
  res.json({ success: true, message: 'Subject created successfully.', id });
});

// ==================== TEACHER ASSIGNMENTS ====================
router.get('/teacher-assignments', authenticateToken, async (req, res) => {
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

  const assignments = await query(sql, params);
  res.json({ success: true, data: assignments });
});

router.post('/teacher-assignments', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { teacher_id, batch_id, subject_id, academic_session_id } = req.body;
  if (!teacher_id || !batch_id || !subject_id || !academic_session_id) {
    return res.status(400).json({ success: false, error: 'All assignment fields are required.' });
  }

  const id = 'ta-' + Date.now();
  await run(
    `INSERT OR REPLACE INTO teacher_assignments (id, teacher_id, batch_id, subject_id, academic_session_id)
     VALUES (?, ?, ?, ?, ?)`,
    [id, teacher_id, batch_id, subject_id, academic_session_id]
  );

  await logAudit(req.user.id, 'ASSIGN_TEACHER', 'teacher_assignments', id, { teacher_id, batch_id, subject_id }, req);
  res.json({ success: true, message: 'Teacher assigned to batch successfully.', id });
});

// ==================== STUDENTS ENROLLMENT & MANAGEMENT ====================
router.get('/students', authenticateToken, authorizeRoles('admin', 'teacher'), async (req, res) => {
  const { batch_id, class_id, status, subscription_status, search } = req.query;
  let sql = `
    SELECT u.id, u.name, u.email, u.phone, u.avatar_url, u.is_active,
           u.google_uid, u.phone_verified, u.status as user_status, u.created_at,
           sp.student_id_number, sp.class_id, sp.batch_id, sp.academic_session_id, sp.emergency_contact,
           sp.subscription_status, sp.access_start_date, sp.access_end_date,
           sp.resource_permissions_json,
           c.name as class_name, b.name as batch_name, s.name as session_name
    FROM users u
    JOIN student_profiles sp ON u.id = sp.user_id
    LEFT JOIN classes c ON sp.class_id = c.id
    LEFT JOIN batches b ON sp.batch_id = b.id
    LEFT JOIN academic_sessions s ON sp.academic_session_id = s.id
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
  if (status) {
    sql += ' AND u.status = ?';
    params.push(status);
  }
  if (subscription_status) {
    sql += ' AND sp.subscription_status = ?';
    params.push(subscription_status);
  }
  if (search && search.trim()) {
    const s = `%${search.trim().toLowerCase()}%`;
    sql += ' AND (LOWER(u.name) LIKE ? OR LOWER(u.email) LIKE ? OR LOWER(sp.student_id_number) LIKE ? OR u.phone LIKE ?)';
    params.push(s, s, s, s);
  }

  sql += ' ORDER BY sp.student_id_number ASC, u.name ASC';
  const rawStudents = await query(sql, params);
  const students = rawStudents.map(stu => {
    try {
      stu.resource_permissions = typeof stu.resource_permissions_json === 'string'
        ? JSON.parse(stu.resource_permissions_json)
        : stu.resource_permissions_json;
    } catch (_) {
      stu.resource_permissions = { materials: true, doubts: true, exams: true };
    }
    return stu;
  });
  res.json({ success: true, data: students, total: students.length });
});

// Collision-safe Student ID generator: BST-2027-00001
async function generateUniqueStudentId(year = '2027') {
  let counter = 1;
  while (counter < 100000) {
    const candidate = `BST-${year}-${String(counter).padStart(5, '0')}`;
    const exists = await get('SELECT id FROM student_profiles WHERE student_id_number = ?', [candidate]);
    if (!exists) {
      return candidate;
    }
    counter++;
  }
  return `BST-${year}-${Date.now().toString().slice(-5)}`;
}

// Admin creates/provisions student (Collision-safe Student ID, subscription status, access dates)
router.post('/students', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const {
    name,
    email,
    password,
    phone,
    student_id_number,
    class_id,
    batch_id,
    academic_session_id,
    emergency_contact,
    subscription_status = 'paid',
    access_start_date,
    access_end_date,
    resource_permissions
  } = req.body;

  if (!name || !email || !batch_id || !class_id || !academic_session_id) {
    return res.status(400).json({ success: false, error: 'Name, email, class, batch, and session are required.' });
  }

  const existing = await get('SELECT id FROM users WHERE email = ?', [email.trim().toLowerCase()]);
  if (existing) {
    return res.status(400).json({ success: false, error: 'User with this email already exists.' });
  }

  // Auto-generate or validate unique student ID
  const finalStudentId = (student_id_number && student_id_number.trim())
    ? student_id_number.trim().toUpperCase()
    : await generateUniqueStudentId();

  const idCollision = await get('SELECT id FROM student_profiles WHERE student_id_number = ?', [finalStudentId]);
  if (idCollision) {
    return res.status(409).json({ success: false, error: `Student ID "${finalStudentId}" is already assigned.` });
  }

  const userId = 'user-stu-' + Date.now();
  const profileId = 'stu-prof-' + Date.now();
  const enrollmentId = 'enr-' + Date.now();
  const passwordHash = password ? bcrypt.hashSync(password, 10) : bcrypt.hashSync(Math.random().toString(36), 10);
  const permissionsJson = typeof resource_permissions === 'object'
    ? JSON.stringify(resource_permissions)
    : '{"materials": true, "doubts": true, "exams": true}';

  await transaction(async () => {
    await run(
      `INSERT INTO users (id, email, password_hash, role, name, phone, phone_verified, status, is_active)
       VALUES (?, ?, ?, 'student', ?, ?, 0, 'pending_activation', 1)`,
      [userId, email.trim().toLowerCase(), passwordHash, name, phone || null]
    );

    await run(
      `INSERT INTO student_profiles 
       (id, user_id, student_id_number, class_id, batch_id, academic_session_id, subscription_status, access_start_date, access_end_date, resource_permissions_json, emergency_contact)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        profileId,
        userId,
        finalStudentId,
        class_id,
        batch_id,
        academic_session_id,
        subscription_status,
        access_start_date || new Date().toISOString(),
        access_end_date || null,
        permissionsJson,
        emergency_contact || null
      ]
    );

    await run(
      `INSERT INTO enrollments (id, student_id, batch_id, academic_session_id, status)
       VALUES (?, ?, ?, ?, 'active')`,
      [enrollmentId, userId, batch_id, academic_session_id]
    );
  });

  await logAudit(req.user.id, 'PROVISION_STUDENT', 'users', userId, { name, email, student_id_number: finalStudentId, batch_id, subscription_status }, req);
  res.json({
    success: true,
    message: 'Student provisioned successfully. Student ID generated.',
    id: userId,
    studentIdNumber: finalStudentId
  });
});

// Student detail view (Profile, Enrollment, Academic Progress, Activity)
router.get('/students/:id', authenticateToken, authorizeRoles('admin', 'teacher'), async (req, res) => {
  const { id } = req.params;

  const stu = await get(`
    SELECT u.id, u.name, u.email, u.phone, u.avatar_url, u.is_active,
           u.google_uid, u.phone_verified, u.status, u.last_login_at, u.created_at,
           sp.id as profile_id, sp.student_id_number, sp.class_id, sp.batch_id, sp.academic_session_id, sp.emergency_contact,
           sp.subscription_status, sp.access_start_date, sp.access_end_date, sp.resource_permissions_json,
           c.name as class_name, c.stream as class_stream,
           b.name as batch_name,
           s.name as session_name
    FROM users u
    JOIN student_profiles sp ON u.id = sp.user_id
    LEFT JOIN classes c ON sp.class_id = c.id
    LEFT JOIN batches b ON sp.batch_id = b.id
    LEFT JOIN academic_sessions s ON sp.academic_session_id = s.id
    WHERE u.id = ? AND u.role = 'student'
  `, [id]);

  if (!stu) {
    return res.status(404).json({ success: false, error: 'Student not found.' });
  }

  try {
    stu.resource_permissions = typeof stu.resource_permissions_json === 'string'
      ? JSON.parse(stu.resource_permissions_json)
      : stu.resource_permissions_json;
  } catch (_) {
    stu.resource_permissions = { materials: true, doubts: true, exams: true };
  }

  // Summary stats for administrative insight
  const attendanceStats = await get(
    'SELECT count(*) as total, SUM(is_present) as present FROM attendance WHERE student_id = ?',
    [id]
  );
  const doubtRow = await get('SELECT count(*) as count FROM doubts WHERE student_id = ?', [id]);
  const doubtCount = doubtRow?.count || 0;
  const subRow = await get('SELECT count(*) as count FROM assignment_submissions WHERE student_id = ?', [id]);
  const submissionCount = subRow?.count || 0;

  res.json({
    success: true,
    data: {
      ...stu,
      stats: {
        totalLectures: attendanceStats?.total || 0,
        attendedLectures: attendanceStats?.present || 0,
        attendancePercentage: attendanceStats?.total ? Math.round((attendanceStats.present / attendanceStats.total) * 100) : 0,
        doubtsAsked: doubtCount,
        assignmentsSubmitted: submissionCount
      }
    }
  });
});

// Edit student details (name, phone, emergency contact, class_id, batch_id, academic_session_id)
router.put('/students/:id', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { id } = req.params;
  const { name, phone, emergency_contact, class_id, batch_id, academic_session_id } = req.body;

  const stu = await get('SELECT id, name, email FROM users WHERE id = ? AND role = \'student\'', [id]);
  if (!stu) {
    return res.status(404).json({ success: false, error: 'Student not found.' });
  }

  await transaction(async () => {
    if (name || phone !== undefined) {
      await run(
        "UPDATE users SET name = COALESCE(?, name), phone = COALESCE(?, phone), updated_at = datetime('now') WHERE id = ?",
        [name || null, phone !== undefined ? phone : null, id]
      );
    }

    if (emergency_contact !== undefined || class_id || batch_id || academic_session_id) {
      await run(
        `UPDATE student_profiles
         SET emergency_contact = COALESCE(?, emergency_contact),
             class_id = COALESCE(?, class_id),
             batch_id = COALESCE(?, batch_id),
             academic_session_id = COALESCE(?, academic_session_id),
             updated_at = datetime('now')
         WHERE user_id = ?`,
        [emergency_contact !== undefined ? emergency_contact : null, class_id || null, batch_id || null, academic_session_id || null, id]
      );
    }

    if (batch_id || academic_session_id) {
      await run(
        `UPDATE enrollments
         SET batch_id = COALESCE(?, batch_id),
             academic_session_id = COALESCE(?, academic_session_id)
         WHERE student_id = ?`,
        [batch_id || null, academic_session_id || null, id]
      );
    }
  });

  await logAudit(req.user.id, 'UPDATE_STUDENT_PROFILE', 'users', id, {
    name,
    phone,
    class_id,
    batch_id,
    academic_session_id
  }, req);

  res.json({ success: true, message: 'Student profile updated successfully.' });
});

// Suspend student
router.post('/students/:id/suspend', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  const stu = await get('SELECT id, name, email FROM users WHERE id = ? AND role = \'student\'', [id]);
  if (!stu) {
    return res.status(404).json({ success: false, error: 'Student not found.' });
  }

  await run("UPDATE users SET status = 'suspended', is_active = 0, updated_at = datetime('now') WHERE id = ?", [id]);
  await logAudit(req.user.id, 'SUSPEND_STUDENT', 'users', id, { name: stu.name, email: stu.email, reason: reason || 'Administrative suspension' }, req);
  res.json({ success: true, message: `Student "${stu.name}" has been suspended.` });
});

// Restore suspended or archived student
router.post('/students/:id/restore', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { id } = req.params;

  const stu = await get('SELECT id, name, email FROM users WHERE id = ? AND role = \'student\'', [id]);
  if (!stu) {
    return res.status(404).json({ success: false, error: 'Student not found.' });
  }

  await run("UPDATE users SET status = 'active', is_active = 1, updated_at = datetime('now') WHERE id = ?", [id]);
  await logAudit(req.user.id, 'RESTORE_STUDENT', 'users', id, { name: stu.name, email: stu.email }, req);
  res.json({ success: true, message: `Student "${stu.name}" has been restored to active status.` });
});

// Archive student (Controlled soft-removal preserving historical records)
router.post('/students/:id/archive', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  const stu = await get('SELECT id, name, email FROM users WHERE id = ? AND role = \'student\'', [id]);
  if (!stu) {
    return res.status(404).json({ success: false, error: 'Student not found.' });
  }

  await run("UPDATE users SET status = 'archived', is_active = 0, updated_at = datetime('now') WHERE id = ?", [id]);
  await logAudit(req.user.id, 'ARCHIVE_STUDENT', 'users', id, { name: stu.name, email: stu.email, reason: reason || 'Controlled archival' }, req);
  res.json({ success: true, message: `Student "${stu.name}" has been archived. Portal access is disabled and academic records preserved.` });
});

// Update student subscription and resource permissions
router.put('/students/:id/subscription', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { id } = req.params;
  const { subscription_status, access_start_date, access_end_date, resource_permissions } = req.body;

  const stu = await get('SELECT id, name FROM users WHERE id = ? AND role = \'student\'', [id]);
  if (!stu) {
    return res.status(404).json({ success: false, error: 'Student not found.' });
  }

  const validTiers = ['paid', 'free', 'expired', 'suspended', 'archived'];
  if (subscription_status && !validTiers.includes(subscription_status)) {
    return res.status(400).json({ success: false, error: 'Invalid subscription_status. Must be one of: ' + validTiers.join(', ') });
  }

  const permsJson = resource_permissions !== undefined
    ? (typeof resource_permissions === 'object' ? JSON.stringify(resource_permissions) : resource_permissions)
    : null;

  await run(
    `UPDATE student_profiles 
     SET subscription_status = COALESCE(?, subscription_status),
         access_start_date = COALESCE(?, access_start_date),
         access_end_date = COALESCE(?, access_end_date),
         resource_permissions_json = COALESCE(?, resource_permissions_json),
         updated_at = datetime('now')
     WHERE user_id = ?`,
    [subscription_status || null, access_start_date || null, access_end_date || null, permsJson, id]
  );

  await logAudit(req.user.id, 'UPDATE_STUDENT_SUBSCRIPTION', 'student_profiles', id, {
    studentName: stu.name,
    subscription_status,
    access_end_date,
    resource_permissions
  }, req);

  res.json({ success: true, message: 'Student subscription and resource permissions updated successfully.' });
});

// Admin updates student status (suspend, reactivate, expire, set paid/free)
router.put('/students/:id/status', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { id } = req.params;
  const { status, subscription_status, access_end_date } = req.body;

  const user = await get('SELECT id, role FROM users WHERE id = ? AND role = \'student\'', [id]);
  if (!user) {
    return res.status(404).json({ success: false, error: 'Student not found.' });
  }

  await transaction(async () => {
    if (status) {
      const validStatuses = ['active', 'pending_activation', 'suspended', 'archived', 'expired'];
      if (!validStatuses.includes(status)) {
        throw new Error('Invalid status value. Must be one of: ' + validStatuses.join(', '));
      }
      await run("UPDATE users SET status = ?, is_active = ?, updated_at = datetime('now') WHERE id = ?", [
        status,
        (status === 'suspended' || status === 'archived') ? 0 : 1,
        id
      ]);
    }

    if (subscription_status || access_end_date !== undefined) {
      if (subscription_status) {
        const validTiers = ['paid', 'free', 'expired', 'suspended', 'archived'];
        if (!validTiers.includes(subscription_status)) {
          throw new Error('Invalid subscription_status. Must be one of: ' + validTiers.join(', '));
        }
        await run("UPDATE student_profiles SET subscription_status = ?, updated_at = datetime('now') WHERE user_id = ?", [
          subscription_status,
          id
        ]);
      }
      if (access_end_date !== undefined) {
        await run("UPDATE student_profiles SET access_end_date = ?, updated_at = datetime('now') WHERE user_id = ?", [
          access_end_date,
          id
        ]);
      }
    }
  });

  await logAudit(req.user.id, 'UPDATE_STUDENT_STATUS', 'users', id, { status, subscription_status, access_end_date }, req);
  res.json({ success: true, message: 'Student status updated successfully.' });
});

// View student audit logs
router.get('/students/:id/audit', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { id } = req.params;

  const auditLogsRaw = await query(`
    SELECT a.*, actor.name as actor_name, actor.role as actor_role
    FROM audit_logs a
    LEFT JOIN users actor ON a.user_id = actor.id
    WHERE a.user_id = ? OR (a.entity_type = 'users' AND a.entity_id = ?) OR (a.entity_type = 'student_profiles' AND a.entity_id = ?)
    ORDER BY a.created_at DESC
    LIMIT 50
  `, [id, id, id]);

  const auditLogs = auditLogsRaw.map(log => {
    try {
      log.details = typeof log.details_json === 'string' ? JSON.parse(log.details_json) : log.details_json;
    } catch (_) {
      log.details = {};
    }
    return log;
  });

  res.json({ success: true, data: auditLogs });
});

// ==================== TEACHERS MANAGEMENT ====================
router.get('/teachers', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const teachers = await query(
    `SELECT u.id, u.name, u.email, u.phone, u.avatar_url, u.is_active,
            tp.employee_code, tp.qualification, tp.bio, tp.contact_number, tp.joining_date
     FROM users u
     JOIN teacher_profiles tp ON u.id = tp.user_id
     WHERE u.role = 'teacher'
     ORDER BY u.name ASC`
  );
  res.json({ success: true, data: teachers });
});

router.post('/teachers', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { name, email, password, phone, employee_code, qualification, bio } = req.body;

  if (!name || !email || !password || !employee_code) {
    return res.status(400).json({ success: false, error: 'Name, email, password, and employee code are required.' });
  }

  const existing = await get('SELECT id FROM users WHERE email = ?', [email.trim().toLowerCase()]);
  if (existing) {
    return res.status(400).json({ success: false, error: 'User with this email already exists.' });
  }

  const userId = 'user-tch-' + Date.now();
  const profileId = 'tch-prof-' + Date.now();
  const passwordHash = bcrypt.hashSync(password, 10);

  await transaction(async () => {
    await run(
      'INSERT INTO users (id, email, password_hash, role, name, phone) VALUES (?, ?, ?, ?, ?, ?)',
      [userId, email.trim().toLowerCase(), passwordHash, 'teacher', name, phone || null]
    );

    await run(
      `INSERT INTO teacher_profiles (id, user_id, employee_code, qualification, bio, contact_number)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [profileId, userId, employee_code, qualification || '', bio || '', phone || '']
    );
  });

  await logAudit(req.user.id, 'CREATE_TEACHER', 'users', userId, { name, email, employee_code }, req);
  res.json({ success: true, message: 'Teacher registered successfully.', id: userId });
});

module.exports = router;
