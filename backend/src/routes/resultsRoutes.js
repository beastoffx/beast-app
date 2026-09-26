const express = require('express');
const { query, get, run, transaction } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');

const router = express.Router();

function calculateGrade(percentage) {
  if (percentage >= 90) return 'A+';
  if (percentage >= 80) return 'A';
  if (percentage >= 70) return 'B+';
  if (percentage >= 60) return 'B';
  if (percentage >= 50) return 'C';
  if (percentage >= 40) return 'D';
  return 'F';
}

// GET /api/results/my - Student sees their own published results
router.get('/my', authenticateToken, authorizeRoles('student'), async (req, res) => {
  const studentId = req.user.id;

  const results = await query(
    `SELECT r.*, es.exam_date, es.passing_marks,
            e.title as exam_title, e.exam_type,
            s.name as subject_name, s.code as subject_code,
            u.name as entered_by_name
     FROM results r
     JOIN exam_subjects es ON r.exam_subject_id = es.id
     JOIN exams e ON es.exam_id = e.id
     JOIN subjects s ON es.subject_id = s.id
     JOIN users u ON r.entered_by = u.id
     WHERE r.student_id = ?
     ORDER BY es.exam_date DESC`,
    [studentId]
  );

  // Calculate overall performance summary
  let totalMarksObtained = 0;
  let totalMaxMarks = 0;
  results.forEach(r => {
    totalMarksObtained += r.marks_obtained;
    totalMaxMarks += r.max_marks;
  });

  const cumulativePercentage = totalMaxMarks > 0 ? Math.round((totalMarksObtained / totalMaxMarks) * 1000) / 10 : 0.0;
  const overallGrade = calculateGrade(cumulativePercentage);

  res.json({
    success: true,
    data: {
      results,
      summary: {
        totalExams: results.length,
        totalMarksObtained,
        totalMaxMarks,
        cumulativePercentage,
        overallGrade
      }
    }
  });
});

// GET /api/results/exam-subject/:examSubjectId - Teacher/Admin views results sheet
router.get('/exam-subject/:examSubjectId', authenticateToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  const { examSubjectId } = req.params;

  const subjectInfo = await get(
    `SELECT es.*, s.name as subject_name, s.code as subject_code, e.title as exam_title, e.batch_id
     FROM exam_subjects es
     JOIN subjects s ON es.subject_id = s.id
     JOIN exams e ON es.exam_id = e.id
     WHERE es.id = ?`,
    [examSubjectId]
  );

  if (!subjectInfo) {
    return res.status(404).json({ success: false, error: 'Exam subject not found.' });
  }

  // Fetch all students in the batch and any results entered
  const rows = await query(
    `SELECT u.id as student_id, u.name as student_name, sp.student_id_number,
            r.id as result_id, r.marks_obtained, r.max_marks, r.percentage, r.grade, r.feedback
     FROM enrollments en
     JOIN users u ON en.student_id = u.id
     JOIN student_profiles sp ON u.id = sp.user_id
     LEFT JOIN results r ON (r.student_id = u.id AND r.exam_subject_id = ?)
     WHERE en.batch_id = ? AND en.status = 'active'
     ORDER BY u.name ASC`,
    [examSubjectId, subjectInfo.batch_id]
  );

  res.json({
    success: true,
    data: {
      subjectInfo,
      students: rows
    }
  });
});

// POST /api/results/batch - Teacher/Admin enters or updates marks for multiple students
router.post('/batch', authenticateToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  const { exam_subject_id, marks_data } = req.body;
  // marks_data: Array of { student_id, marks_obtained, max_marks, feedback }

  if (!exam_subject_id || !Array.isArray(marks_data) || marks_data.length === 0) {
    return res.status(400).json({ success: false, error: 'Exam subject and marks array are required.' });
  }

  await transaction(async () => {
    for (const item of marks_data) {
      const maxMarks = item.max_marks || 100;
      const obtained = parseFloat(item.marks_obtained);
      const percentage = Math.round((obtained / maxMarks) * 1000) / 10;
      const grade = calculateGrade(percentage);

      const existing = await get(
        'SELECT id FROM results WHERE exam_subject_id = ? AND student_id = ?',
        [exam_subject_id, item.student_id]
      );

      if (existing) {
        await run(
          `UPDATE results
           SET marks_obtained = ?, max_marks = ?, percentage = ?, grade = ?, feedback = ?,
               entered_by = ?, updated_at = datetime('now')
           WHERE id = ?`,
          [obtained, maxMarks, percentage, grade, item.feedback || '', req.user.id, existing.id]
        );
      } else {
        const id = 'res-' + Date.now() + '-' + Math.random().toString(36).substring(2, 6);
        await run(
          `INSERT INTO results (id, exam_subject_id, student_id, marks_obtained, max_marks, percentage, grade, feedback, entered_by)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [id, exam_subject_id, item.student_id, obtained, maxMarks, percentage, grade, item.feedback || '', req.user.id]
        );
      }
    }
  });

  await logAudit(req.user.id, 'ENTER_EXAM_RESULTS', 'results', exam_subject_id, { count: marks_data.length }, req);
  res.json({ success: true, message: `Results for ${marks_data.length} students recorded successfully.` });
});

module.exports = router;
