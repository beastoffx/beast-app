const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// GET /api/search?q=...
router.get('/', authenticateToken, async (req, res) => {
  const queryText = (req.query.q || '').trim();
  if (!queryText || queryText.length < 2) {
    return res.json({
      success: true,
      data: {
        subjects: [],
        notices: [],
        materials: [],
        assignments: [],
        doubts: [],
        students: []
      }
    });
  }

  const user = req.user;
  const searchPattern = `%${queryText}%`;

  // 1. Subjects (visible to all)
  const subjects = await query(
    `SELECT s.id, s.name, s.code, c.name as class_name
     FROM subjects s
     JOIN classes c ON s.class_id = c.id
     WHERE s.name LIKE ? OR s.code LIKE ?
     LIMIT 5`,
    [searchPattern, searchPattern]
  );

  // 2. Notices (role-filtered)
  let notices = [];
  if (user.role === 'student') {
    notices = await query(
      `SELECT id, title, category, priority, publish_date
       FROM notices
       WHERE (title LIKE ? OR description LIKE ?)
         AND (target_type = 'all' OR target_id = (SELECT batch_id FROM student_profiles WHERE user_id = ?))
       LIMIT 5`,
      [searchPattern, searchPattern, user.id]
    );
  } else {
    notices = await query(
      `SELECT id, title, category, priority, publish_date
       FROM notices
       WHERE title LIKE ? OR description LIKE ?
       LIMIT 5`,
      [searchPattern, searchPattern]
    );
  }

  // 3. Materials (role-filtered)
  let materials = [];
  if (user.role === 'student') {
    materials = await query(
      `SELECT m.id, m.title, m.chapter, s.name as subject_name
       FROM study_materials m
       JOIN subjects s ON m.subject_id = s.id
       WHERE (m.title LIKE ? OR m.chapter LIKE ?)
         AND (m.batch_id IS NULL OR m.batch_id = (SELECT batch_id FROM student_profiles WHERE user_id = ?))
       LIMIT 5`,
      [searchPattern, searchPattern, user.id]
    );
  } else {
    materials = await query(
      `SELECT m.id, m.title, m.chapter, s.name as subject_name
       FROM study_materials m
       JOIN subjects s ON m.subject_id = s.id
       WHERE m.title LIKE ? OR m.chapter LIKE ?
       LIMIT 5`,
      [searchPattern, searchPattern]
    );
  }

  // 4. Assignments (role-filtered)
  let assignments = [];
  if (user.role === 'student') {
    assignments = await query(
      `SELECT a.id, a.title, a.deadline, s.name as subject_name
       FROM assignments a
       JOIN subjects s ON a.subject_id = s.id
       WHERE (a.title LIKE ? OR a.description LIKE ?)
         AND a.batch_id = (SELECT batch_id FROM student_profiles WHERE user_id = ?)
       LIMIT 5`,
      [searchPattern, searchPattern, user.id]
    );
  } else {
    assignments = await query(
      `SELECT a.id, a.title, a.deadline, s.name as subject_name
       FROM assignments a
       JOIN subjects s ON a.subject_id = s.id
       WHERE a.title LIKE ? OR a.description LIKE ?
       LIMIT 5`,
      [searchPattern, searchPattern]
    );
  }

  // 5. Doubts (Strict privacy: student ONLY sees their own doubts; teacher/admin sees doubts they teach)
  let doubts = [];
  if (user.role === 'student') {
    doubts = await query(
      `SELECT d.id, d.title, d.status, s.name as subject_name
       FROM doubts d
       JOIN subjects s ON d.subject_id = s.id
       WHERE d.student_id = ? AND (d.title LIKE ? OR d.note LIKE ?)
       LIMIT 5`,
      [user.id, searchPattern, searchPattern]
    );
  } else if (user.role === 'teacher') {
    doubts = await query(
      `SELECT d.id, d.title, d.status, s.name as subject_name
       FROM doubts d
       JOIN subjects s ON d.subject_id = s.id
       WHERE (d.title LIKE ? OR d.note LIKE ?)
         AND d.subject_id IN (SELECT subject_id FROM teacher_assignments WHERE teacher_id = ?)
       LIMIT 5`,
      [searchPattern, searchPattern, user.id]
    );
  } else {
    doubts = await query(
      `SELECT d.id, d.title, d.status, s.name as subject_name
       FROM doubts d
       JOIN subjects s ON d.subject_id = s.id
       WHERE d.title LIKE ? OR d.note LIKE ?
       LIMIT 5`,
      [searchPattern, searchPattern]
    );
  }

  // 6. Students (strictly Admin & Teacher only; students can NEVER search other students)
  let students = [];
  if (user.role === 'admin' || user.role === 'teacher') {
    students = await query(
      `SELECT u.id, u.name, u.email, sp.student_id_number, b.name as batch_name
       FROM users u
       JOIN student_profiles sp ON u.id = sp.user_id
       LEFT JOIN batches b ON sp.batch_id = b.id
       WHERE u.role = 'student' AND (u.name LIKE ? OR sp.student_id_number LIKE ?)
       LIMIT 5`,
      [searchPattern, searchPattern]
    );
  }

  res.json({
    success: true,
    data: {
      subjects,
      notices,
      materials,
      assignments,
      doubts,
      students
    }
  });
});

module.exports = router;
