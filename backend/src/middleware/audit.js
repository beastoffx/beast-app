const { run } = require('../db');

async function logAudit(userId, action, entityType, entityId, details, req) {
  try {
    const id = 'audit-' + Date.now() + '-' + Math.random().toString(36).substring(2, 7);
    const ipAddress = req ? (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '') : '';
    const detailsJson = typeof details === 'object' ? JSON.stringify(details) : (details || null);

    await run(
      `INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details_json, ip_address)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, userId || null, action, entityType, entityId || null, detailsJson, ipAddress]
    );
  } catch (err) {
    console.error('[AUDIT_ERROR] Failed to write audit log:', err.message);
  }
}

module.exports = { logAudit };
