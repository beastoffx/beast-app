const express = require('express');
const { query, get, run } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');

const router = express.Router();

// GET /api/fees/my - Student views their fee ledger and status
router.get('/my', authenticateToken, authorizeRoles('student'), (req, res) => {
  const studentId = req.user.id;

  const fees = query(
    `SELECT f.*, s.name as session_name
     FROM fee_records f
     JOIN academic_sessions s ON f.academic_session_id = s.id
     WHERE f.student_id = ?
     ORDER BY f.due_date DESC`,
    [studentId]
  );

  let totalDues = 0;
  let totalPaid = 0;
  fees.forEach(f => {
    totalDues += f.amount;
    totalPaid += (f.paid_amount || 0);
  });

  res.json({
    success: true,
    data: {
      fees,
      summary: {
        totalDues,
        totalPaid,
        outstanding: Math.max(0, totalDues - totalPaid)
      }
    }
  });
});

// GET /api/fees - Admin views institutional fee records with status filter
router.get('/', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { status, student_id } = req.query;
  let sql = `
    SELECT f.*, u.name as student_name, u.email as student_email,
           sp.student_id_number, b.name as batch_name, s.name as session_name
    FROM fee_records f
    JOIN users u ON f.student_id = u.id
    JOIN student_profiles sp ON u.id = sp.user_id
    LEFT JOIN batches b ON sp.batch_id = b.id
    JOIN academic_sessions s ON f.academic_session_id = s.id
    WHERE 1=1
  `;
  const params = [];

  if (status) {
    sql += ' AND f.status = ?';
    params.push(status);
  }
  if (student_id) {
    sql += ' AND f.student_id = ?';
    params.push(student_id);
  }

  sql += ' ORDER BY f.due_date DESC';
  const records = query(sql, params);

  // Financial summary
  const totalStats = get(
    `SELECT
       SUM(amount) as total_billed,
       SUM(paid_amount) as total_collected,
       SUM(CASE WHEN status = 'pending' OR status = 'overdue' THEN (amount - paid_amount) ELSE 0 END) as total_outstanding
     FROM fee_records`
  );

  res.json({
    success: true,
    data: {
      records,
      stats: {
        totalBilled: totalStats.total_billed || 0,
        totalCollected: totalStats.total_collected || 0,
        totalOutstanding: totalStats.total_outstanding || 0
      }
    }
  });
});

// POST /api/fees - Admin creates a fee invoice for a student
router.post('/', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { student_id, academic_session_id, fee_title, amount, due_date, notes } = req.body;

  if (!student_id || !academic_session_id || !fee_title || !amount || !due_date) {
    return res.status(400).json({ success: false, error: 'Student, session, fee title, amount, and due date are required.' });
  }

  const id = 'fee-' + Date.now();
  run(
    `INSERT INTO fee_records (id, student_id, academic_session_id, fee_title, amount, due_date, status, paid_amount, notes)
     VALUES (?, ?, ?, ?, ?, ?, 'pending', 0, ?)`,
    [id, student_id, academic_session_id, fee_title, parseFloat(amount), due_date, notes || '']
  );

  logAudit(req.user.id, 'CREATE_FEE_RECORD', 'fee_records', id, { student_id, amount }, req);
  res.json({ success: true, message: 'Fee invoice generated successfully.', id });
});

// PUT /api/fees/:id/record-payment - Admin updates payment details
router.put('/:id/record-payment', authenticateToken, authorizeRoles('admin'), (req, res) => {
  const { id } = req.params;
  const { paid_amount, payment_date, receipt_reference, notes } = req.body;

  const fee = get('SELECT * FROM fee_records WHERE id = ?', [id]);
  if (!fee) {
    return res.status(404).json({ success: false, error: 'Fee record not found.' });
  }

  const newPaidAmount = parseFloat(paid_amount);
  let newStatus = 'pending';
  if (newPaidAmount >= fee.amount) {
    newStatus = 'paid';
  } else if (newPaidAmount > 0) {
    newStatus = 'partial';
  }

  run(
    `UPDATE fee_records
     SET paid_amount = ?, status = ?, payment_date = ?, receipt_reference = ?, notes = ?, updated_at = datetime('now')
     WHERE id = ?`,
    [
      newPaidAmount,
      newStatus,
      payment_date || new Date().toISOString().split('T')[0],
      receipt_reference || `REC-${Date.now().toString().slice(-6)}`,
      notes || fee.notes,
      id
    ]
  );

  logAudit(req.user.id, 'RECORD_FEE_PAYMENT', 'fee_records', id, { newPaidAmount, newStatus }, req);
  res.json({ success: true, message: 'Payment status updated successfully.' });
});

module.exports = router;
