const express = require('express');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');

const router = express.Router();

// GET /api/audit-logs - Admin views audit trail
router.get('/', authenticateToken, authorizeRoles('admin'), async (req, res) => {
  const { limit = 50, entity_type } = req.query;
  let sql = `
    SELECT a.*, u.name as user_name, u.email as user_email, u.role as user_role
    FROM audit_logs a
    LEFT JOIN users u ON a.user_id = u.id
  `;
  const params = [];

  if (entity_type) {
    sql += ' WHERE a.entity_type = ?';
    params.push(entity_type);
  }

  sql += ' ORDER BY a.created_at DESC LIMIT ?';
  params.push(parseInt(limit, 10));

  const logs = await query(sql, params);
  res.json({ success: true, data: logs });
});

module.exports = router;
