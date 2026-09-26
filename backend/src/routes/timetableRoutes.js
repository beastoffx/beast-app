const express = require('express');
const { query, get, run } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');

const router = express.Router();

// GET /api/timetable/my - Personalized for logged-in Student or Teacher
router.get('/my', authenticateToken, async (req, res) => {
  const user = req.user;
  let sql = '';
  let params = [];

  if (user.role === 'student') {
    if (user.access_end_date && new Date(user.access_end_date) < new Date()) {
      return res.status(403).json({
        success: false,
        error: 'Your academic subscription has expired. Please contact administration.'
      });
    }
    if (user.resource_permissions && (user.resource_permissions.live_lectures === false || user.resource_permissions.lectures === false)) {
      return res.status(403).json({
        success: false,
        error: 'Live lectures access is not enabled for your student tier.'
      });
    }
    // Student sees timetable for the batch they are enrolled in
    sql = `
      SELECT t.*, s.name as subject_name, s.code as subject_code,
             u.name as teacher_name, b.name as batch_name
      FROM timetables t
      JOIN subjects s ON t.subject_id = s.id
      JOIN users u ON t.teacher_id = u.id
      JOIN batches b ON t.batch_id = b.id
      WHERE t.batch_id = (SELECT batch_id FROM student_profiles WHERE user_id = ?)
      ORDER BY t.day_of_week ASC, t.start_time ASC
    `;
    params = [user.id];
  } else if (user.role === 'teacher') {
    // Teacher sees their assigned timetable slots
    sql = `
      SELECT t.*, s.name as subject_name, s.code as subject_code,
             u.name as teacher_name, b.name as batch_name
      FROM timetables t
      JOIN subjects s ON t.subject_id = s.id
      JOIN users u ON t.teacher_id = u.id
      JOIN batches b ON t.batch_id = b.id
      WHERE t.teacher_id = ?
      ORDER BY t.day_of_week ASC, t.start_time ASC
    `;
    params = [user.id];
  } else if (user.role === 'admin') {
    // Admin sees full schedule
    sql = `
      SELECT t.*, s.name as subject_name, s.code as subject_code,
             u.name as teacher_name, b.name as batch_name
      FROM timetables t
      JOIN subjects s ON t.subject_id = s.id
      JOIN users u ON t.teacher_id = u.id
      JOIN batches b ON t.batch_id = b.id
      ORDER BY t.day_of_week ASC, t.start_time ASC
    `;
    params = [];
  }

  const schedule = await query(sql, params);

  // Calculate "Today", "Next Class", "This Week"
  // JS Day of week: 0 is Sun, 1 is Mon, 6 is Sat -> ISO Day: 1 is Mon, 7 is Sun
  const todayJs = new Date().getDay();
  const currentDayOfWeek = todayJs === 0 ? 7 : todayJs;
  const currentTimeStr = new Date().toTimeString().substring(0, 5); // "HH:MM"

  const todayClasses = schedule.filter(slot => slot.day_of_week === currentDayOfWeek);
  const nextClass = todayClasses.find(slot => slot.start_time >= currentTimeStr) ||
                    (todayClasses.length > 0 ? todayClasses[0] : null);

  res.json({
    success: true,
    data: {
      schedule,
      todayClasses,
      nextClass,
      currentDayOfWeek
    }
  });
});

// GET /api/timetable/batch/:batchId
router.get('/batch/:batchId', authenticateToken, async (req, res) => {
  const { batchId } = req.params;
  const slots = await query(
    `SELECT t.*, s.name as subject_name, s.code as subject_code,
            u.name as teacher_name, b.name as batch_name
     FROM timetables t
     JOIN subjects s ON t.subject_id = s.id
     JOIN users u ON t.teacher_id = u.id
     JOIN batches b ON t.batch_id = b.id
     WHERE t.batch_id = ?
     ORDER BY t.day_of_week ASC, t.start_time ASC`,
    [batchId]
  );
  res.json({ success: true, data: slots });
});

// POST /api/timetable - Admin adds schedule slot with collision detection
router.post('/', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { batch_id, subject_id, teacher_id, day_of_week, start_time, end_time, room_number } = req.body;

  if (!batch_id || !subject_id || !teacher_id || !day_of_week || !start_time || !end_time) {
    return res.status(400).json({ success: false, error: 'All timetable slot details are required.' });
  }

  // 1. Double-booking check: Teacher collision
  const teacherConflict = await get(
    `SELECT t.*, b.name as batch_name FROM timetables t
     JOIN batches b ON t.batch_id = b.id
     WHERE t.teacher_id = ? AND t.day_of_week = ?
       AND ((t.start_time <= ? AND t.end_time > ?) OR (t.start_time < ? AND t.end_time >= ?) OR (t.start_time >= ? AND t.end_time <= ?))`,
    [teacher_id, day_of_week, start_time, start_time, end_time, end_time, start_time, end_time]
  );
  if (teacherConflict) {
    return res.status(409).json({
      success: false,
      error: `Teacher is already scheduled with batch '${teacherConflict.batch_name}' from ${teacherConflict.start_time} to ${teacherConflict.end_time}.`
    });
  }

  // 2. Double-booking check: Batch collision
  const batchConflict = await get(
    `SELECT t.*, s.name as subject_name FROM timetables t
     JOIN subjects s ON t.subject_id = s.id
     WHERE t.batch_id = ? AND t.day_of_week = ?
       AND ((t.start_time <= ? AND t.end_time > ?) OR (t.start_time < ? AND t.end_time >= ?) OR (t.start_time >= ? AND t.end_time <= ?))`,
    [batch_id, day_of_week, start_time, start_time, end_time, end_time, start_time, end_time]
  );
  if (batchConflict) {
    return res.status(409).json({
      success: false,
      error: `Batch already has '${batchConflict.subject_name}' scheduled from ${batchConflict.start_time} to ${batchConflict.end_time}.`
    });
  }

  const id = 'tt-' + Date.now();
  await run(
    `INSERT INTO timetables (id, batch_id, subject_id, teacher_id, day_of_week, start_time, end_time, room_number)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [id, batch_id, subject_id, teacher_id, day_of_week, start_time, end_time, room_number || 'Hall 1']
  );

  await logAudit(req.user.id, 'CREATE_TIMETABLE_SLOT', 'timetables', id, { batch_id, subject_id, teacher_id, day_of_week, start_time }, req);
  res.json({ success: true, message: 'Class scheduled successfully.', id });
});

// DELETE /api/timetable/:id
router.delete('/:id', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { id } = req.params;
  await run('DELETE FROM timetables WHERE id = ?', [id]);
  await logAudit(req.user.id, 'DELETE_TIMETABLE_SLOT', 'timetables', id, {}, req);
  res.json({ success: true, message: 'Timetable slot deleted.' });
});

module.exports = router;
