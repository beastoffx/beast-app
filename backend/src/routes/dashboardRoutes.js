const express = require('express');
const { query, get } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');

const router = express.Router();

// GET /api/dashboard/student
router.get('/student', authenticateToken, authorizeRoles('student'), (req, res) => {
  const studentId = req.user.id;

  // Student profile and batch
  const profile = get(
    `SELECT sp.*, b.name as batch_name, c.name as class_name
     FROM student_profiles sp
     LEFT JOIN batches b ON sp.batch_id = b.id
     LEFT JOIN classes c ON sp.class_id = c.id
     WHERE sp.user_id = ?`,
    [studentId]
  );

  const batchId = profile ? profile.batch_id : null;

  // Today's classes & next class
  const todayJs = new Date().getDay();
  const currentDayOfWeek = todayJs === 0 ? 7 : todayJs;
  const currentTime = new Date().toTimeString().substring(0, 5);

  const todayClasses = query(
    `SELECT t.*, s.name as subject_name, s.code as subject_code, u.name as teacher_name
     FROM timetables t
     JOIN subjects s ON t.subject_id = s.id
     JOIN users u ON t.teacher_id = u.id
     WHERE t.batch_id = ? AND t.day_of_week = ?
     ORDER BY t.start_time ASC`,
    [batchId, currentDayOfWeek]
  );

  const nextClass = todayClasses.find(c => c.start_time >= currentTime) || null;

  // Attendance summary
  const attStats = get(
    `SELECT
       COUNT(*) as total,
       SUM(CASE WHEN status = 'present' OR status = 'late' THEN 1 ELSE 0 END) as attended
     FROM attendance WHERE student_id = ?`,
    [studentId]
  );
  const totalClasses = attStats.total || 0;
  const attended = attStats.attended || 0;
  const attendancePercentage = totalClasses > 0 ? Math.round((attended / totalClasses) * 1000) / 10 : 100.0;

  // Pending assignments
  const pendingAssignments = query(
    `SELECT a.*, s.name as subject_name
     FROM assignments a
     JOIN subjects s ON a.subject_id = s.id
     LEFT JOIN assignment_submissions sub ON (a.id = sub.assignment_id AND sub.student_id = ?)
     WHERE a.batch_id = ? AND sub.id IS NULL
     ORDER BY a.deadline ASC
     LIMIT 5`,
    [studentId, batchId]
  );

  // Recent notices (top 3)
  const recentNotices = query(
    `SELECT * FROM notices
     WHERE target_type = 'all' OR (target_type = 'batch' AND target_id = ?)
     ORDER BY is_pinned DESC, publish_date DESC
     LIMIT 3`,
    [batchId]
  );

  // Upcoming exams (next 30 days)
  const upcomingExams = query(
    `SELECT e.*, es.exam_date, es.start_time, s.name as subject_name
     FROM exams e
     JOIN exam_subjects es ON e.id = es.exam_id
     JOIN subjects s ON es.subject_id = s.id
     WHERE (e.batch_id IS NULL OR e.batch_id = ?)
       AND es.exam_date >= date('now')
     ORDER BY es.exam_date ASC
     LIMIT 3`,
    [batchId]
  );

  // Recent materials
  const recentMaterials = query(
    `SELECT m.*, s.name as subject_name
     FROM study_materials m
     JOIN subjects s ON m.subject_id = s.id
     WHERE (m.batch_id IS NULL OR m.batch_id = ?)
     ORDER BY m.created_at DESC
     LIMIT 3`,
    [batchId]
  );

  // Open doubts count
  const openDoubtsCount = get(
    `SELECT COUNT(*) as count FROM doubts WHERE student_id = ? AND status != 'resolved'`,
    [studentId]
  ).count || 0;

  res.json({
    success: true,
    data: {
      profile,
      todayClasses,
      nextClass,
      attendancePercentage,
      totalClasses,
      pendingAssignments,
      recentNotices,
      upcomingExams,
      recentMaterials,
      openDoubtsCount
    }
  });
});

// GET /api/dashboard/teacher
router.get('/teacher', authenticateToken, authorizeRoles('teacher'), (req, res) => {
  const teacherId = req.user.id;

  // Today's classes
  const todayJs = new Date().getDay();
  const currentDayOfWeek = todayJs === 0 ? 7 : todayJs;
  const currentTime = new Date().toTimeString().substring(0, 5);
  const todayStr = new Date().toISOString().split('T')[0];

  const todayClasses = query(
    `SELECT t.*, s.name as subject_name, b.name as batch_name,
            (SELECT COUNT(*) FROM attendance a WHERE a.batch_id = t.batch_id AND a.subject_id = t.subject_id AND a.date = ?) as attendance_taken
     FROM timetables t
     JOIN subjects s ON t.subject_id = s.id
     JOIN batches b ON t.batch_id = b.id
     WHERE t.teacher_id = ? AND t.day_of_week = ?
     ORDER BY t.start_time ASC`,
    [todayStr, teacherId, currentDayOfWeek]
  );

  const nextClass = todayClasses.find(c => c.start_time >= currentTime) || null;

  // Assigned batches
  const assignedBatches = query(
    `SELECT DISTINCT b.id, b.name, c.name as class_name, s.name as subject_name, s.id as subject_id
     FROM teacher_assignments ta
     JOIN batches b ON ta.batch_id = b.id
     JOIN classes c ON b.class_id = c.id
     JOIN subjects s ON ta.subject_id = s.id
     WHERE ta.teacher_id = ?`,
    [teacherId]
  );

  // Submissions to review
  const pendingReviews = query(
    `SELECT sub.*, a.title as assignment_title, u.name as student_name
     FROM assignment_submissions sub
     JOIN assignments a ON sub.assignment_id = a.id
     JOIN users u ON sub.student_id = u.id
     WHERE a.teacher_id = ? AND sub.status = 'submitted'
     ORDER BY sub.submitted_at ASC
     LIMIT 5`,
    [teacherId]
  );

  // Pending doubts
  const pendingDoubts = query(
    `SELECT d.*, s.name as subject_name, u.name as student_name
     FROM doubts d
     JOIN subjects s ON d.subject_id = s.id
     JOIN users u ON d.student_id = u.id
     WHERE d.subject_id IN (SELECT subject_id FROM teacher_assignments WHERE teacher_id = ?)
       AND (d.status = 'open' OR d.status = 'in_discussion')
     ORDER BY d.created_at DESC
     LIMIT 5`,
    [teacherId]
  );

  // Notices
  const recentNotices = query('SELECT * FROM notices ORDER BY publish_date DESC LIMIT 3');

  res.json({
    success: true,
    data: {
      todayClasses,
      nextClass,
      assignedBatches,
      pendingReviewsCount: pendingReviews.length,
      pendingReviews,
      pendingDoubtsCount: pendingDoubts.length,
      pendingDoubts,
      recentNotices
    }
  });
});

// GET /api/dashboard/admin
router.get('/admin', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const todayJs = new Date().getDay();
  const currentDayOfWeek = todayJs === 0 ? 7 : todayJs;
  const todayStr = new Date().toISOString().split('T')[0];

  // Actionable TODAY Metrics
  // 1. Classes scheduled today
  const todayClassesCount = get(
    'SELECT COUNT(*) as count FROM timetables WHERE day_of_week = ?',
    [currentDayOfWeek]
  ).count || 0;

  // 2. Attendance records taken today
  const attendanceMarkedToday = get(
    'SELECT COUNT(DISTINCT batch_id || subject_id) as count FROM attendance WHERE date = ?',
    [todayStr]
  ).count || 0;

  const attendancePendingCount = Math.max(0, todayClassesCount - attendanceMarkedToday);

  // 3. Submissions pending review
  const assignmentsPendingReview = get(
    `SELECT COUNT(*) as count FROM assignment_submissions WHERE status = 'submitted'`
  ).count || 0;

  // 4. Open doubts
  const openDoubtsCount = get(
    `SELECT COUNT(*) as count FROM doubts WHERE status = 'open'`
  ).count || 0;

  // 5. Total counts
  const totalStudents = get(`SELECT COUNT(*) as count FROM users WHERE role = 'student' AND is_active = 1`).count || 0;
  const totalTeachers = get(`SELECT COUNT(*) as count FROM users WHERE role = 'teacher' AND is_active = 1`).count || 0;
  const totalBatches = get(`SELECT COUNT(*) as count FROM batches`).count || 0;
  const totalClasses = get(`SELECT COUNT(*) as count FROM classes`).count || 0;

  // 6. Recent audit logs
  const recentAudit = query(
    `SELECT a.*, u.name as user_name
     FROM audit_logs a
     LEFT JOIN users u ON a.user_id = u.id
     ORDER BY a.created_at DESC
     LIMIT 5`
  );

  // 7. Recent Notices
  const recentNotices = query('SELECT * FROM notices ORDER BY publish_date DESC LIMIT 3');

  res.json({
    success: true,
    data: {
      actionableToday: {
        classesScheduled: todayClassesCount,
        attendancePending: attendancePendingCount,
        assignmentsPendingReview,
        openDoubts: openDoubtsCount
      },
      institutionTotals: {
        totalStudents,
        totalTeachers,
        totalBatches,
        totalClasses
      },
      recentAudit,
      recentNotices
    }
  });
});

module.exports = router;
