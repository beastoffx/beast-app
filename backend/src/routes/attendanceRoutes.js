const express = require('express');
const { query, get, run, transaction } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');

const router = express.Router();

// POST /api/attendance/batch - Teacher or Admin records attendance for a batch & subject on a date
router.post('/batch', authenticateToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  const { batch_id, subject_id, date, records } = req.body;
  // records: Array of { student_id, status: 'present'|'absent'|'late'|'excused', remarks: '' }

  if (!batch_id || !subject_id || !date || !Array.isArray(records) || records.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'Batch, subject, date, and attendance records array are required.'
    });
  }

  // Teacher authorization check: verify teacher is assigned to this batch & subject (unless admin)
  if (req.user.role === 'teacher') {
    const isAssigned = await get(
      'SELECT id FROM teacher_assignments WHERE teacher_id = ? AND batch_id = ? AND subject_id = ?',
      [req.user.id, batch_id, subject_id]
    );
    if (!isAssigned) {
      return res.status(403).json({
        success: false,
        error: 'You are not assigned to teach this subject in this batch.'
      });
    }
  }

  await transaction(async () => {
    for (const rec of records) {
      const existing = await get(
        'SELECT id FROM attendance WHERE batch_id = ? AND subject_id = ? AND student_id = ? AND date = ?',
        [batch_id, subject_id, rec.student_id, date]
      );

      if (existing) {
        await run(
          `UPDATE attendance
           SET status = ?, remarks = ?, marked_by = ?, updated_at = datetime('now')
           WHERE id = ?`,
          [rec.status, rec.remarks || null, req.user.id, existing.id]
        );
      } else {
        const id = 'att-' + Date.now() + '-' + Math.random().toString(36).substring(2, 6);
        await run(
          `INSERT INTO attendance (id, batch_id, subject_id, student_id, date, status, marked_by, remarks)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [id, batch_id, subject_id, rec.student_id, date, rec.status, req.user.id, rec.remarks || null]
        );
      }
    }
  });

  await logAudit(req.user.id, 'RECORD_ATTENDANCE', 'attendance', batch_id, { subject_id, date, count: records.length }, req);

  res.json({
    success: true,
    message: `Attendance for ${records.length} students recorded successfully.`
  });
});

// GET /api/attendance/batch/:batchId - Get attendance sheet for a batch, subject, date
router.get('/batch/:batchId', authenticateToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  const { batchId } = req.params;
  const { date, subject_id } = req.query;

  if (!date || !subject_id) {
    return res.status(400).json({ success: false, error: 'Date and subject_id query parameters are required.' });
  }

  // Fetch all enrolled students in the batch
  const students = await query(
    `SELECT u.id as student_id, u.name as student_name, sp.student_id_number,
            a.id as attendance_id, a.status, a.remarks
     FROM enrollments e
     JOIN users u ON e.student_id = u.id
     JOIN student_profiles sp ON u.id = sp.user_id
     LEFT JOIN attendance a ON (a.student_id = u.id AND a.batch_id = ? AND a.subject_id = ? AND a.date = ?)
     WHERE e.batch_id = ? AND e.status = 'active'
     ORDER BY u.name ASC`,
    [batchId, subject_id, date, batchId]
  );

  res.json({
    success: true,
    data: students
  });
});

// GET /api/attendance/my - Student views their personal attendance summary & history
router.get('/my', authenticateToken, authorizeRoles('student'), async (req, res) => {
  const studentId = req.user.id;

  // Overall attendance statistics
  const stats = await get(
    `SELECT
       COUNT(*) as total_classes,
       SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present_count,
       SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late_count,
       SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent_count,
       SUM(CASE WHEN status = 'excused' THEN 1 ELSE 0 END) as excused_count
     FROM attendance
     WHERE student_id = ?`,
    [studentId]
  );

  const totalClasses = stats.total_classes || 0;
  const presentCount = (stats.present_count || 0) + (stats.late_count || 0); // Late counts as attended
  const overallPercentage = totalClasses > 0 ? Math.round((presentCount / totalClasses) * 1000) / 10 : 0.0;

  // Subject-wise attendance
  const subjectStats = await query(
    `SELECT s.id as subject_id, s.name as subject_name, s.code as subject_code,
            COUNT(*) as total_classes,
            SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present_count,
            SUM(CASE WHEN a.status = 'late' THEN 1 ELSE 0 END) as late_count,
            SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent_count
     FROM attendance a
     JOIN subjects s ON a.subject_id = s.id
     WHERE a.student_id = ?
     GROUP BY s.id, s.name, s.code`,
    [studentId]
  );

  const subjectsWithPercentage = subjectStats.map(s => {
    const total = s.total_classes || 0;
    const present = (s.present_count || 0) + (s.late_count || 0);
    const pct = total > 0 ? Math.round((present / total) * 1000) / 10 : 0.0;
    return { ...s, percentage: pct };
  });

  // Recent 10 attendance records
  const recentRecords = await query(
    `SELECT a.*, s.name as subject_name, u.name as marked_by_name
     FROM attendance a
     JOIN subjects s ON a.subject_id = s.id
     JOIN users u ON a.marked_by = u.id
     WHERE a.student_id = ?
     ORDER BY a.date DESC
     LIMIT 15`,
    [studentId]
  );

  res.json({
    success: true,
    data: {
      overallPercentage,
      totalClasses,
      presentCount,
      absentCount: stats.absent_count || 0,
      lateCount: stats.late_count || 0,
      subjectBreakdown: subjectsWithPercentage,
      recentRecords
    }
  });
});

// GET /api/attendance/summary - Admin institution-wide attendance summary
router.get('/summary', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const summary = await query(
    `SELECT b.id as batch_id, b.name as batch_name, c.name as class_name,
            COUNT(a.id) as total_marks,
            SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) as present_count,
            SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) as absent_count
     FROM batches b
     JOIN classes c ON b.class_id = c.id
     LEFT JOIN attendance a ON b.id = a.batch_id
     GROUP BY b.id, b.name, c.name`
  );

  res.json({ success: true, data: summary });
});

module.exports = router;
