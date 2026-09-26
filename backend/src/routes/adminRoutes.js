const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { query, get, run, transaction } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeSuperAdmin } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');

// Collision-safe Admin ID generator: ADM-2027-00001
function generateUniqueAdminId(year = '2027') {
  let counter = 1;
  while (counter < 100000) {
    const candidate = `ADM-${year}-${String(counter).padStart(5, '0')}`;
    const exists = get('SELECT id FROM admin_profiles WHERE admin_id_number = ?', [candidate]);
    if (!exists) {
      return candidate;
    }
    counter++;
  }
  return `ADM-${year}-${Date.now().toString().slice(-5)}`;
}

// Helper to check if a user is a super admin
function isSuperAdminUser(userId) {
  const user = get('SELECT role FROM users WHERE id = ?', [userId]);
  if (!user) return false;
  if (user.role === 'super_admin') return true;
  const profile = get('SELECT permissions_json FROM admin_profiles WHERE user_id = ?', [userId]);
  if (!profile || !profile.permissions_json) return false;
  try {
    const perms = typeof profile.permissions_json === 'string'
      ? JSON.parse(profile.permissions_json)
      : profile.permissions_json;
    return Boolean(perms.super_admin);
  } catch (_) {
    return false;
  }
}

// Helper to count active super admins
function countActiveSuperAdmins() {
  const admins = query(`
    SELECT u.id, u.role, ap.permissions_json
    FROM users u
    JOIN admin_profiles ap ON u.id = ap.user_id
    WHERE (u.role = 'super_admin' OR u.role = 'admin') AND u.status = 'active'
  `);

  let count = 0;
  for (const adm of admins) {
    if (adm.role === 'super_admin') {
      count++;
      continue;
    }
    try {
      const perms = typeof adm.permissions_json === 'string' ? JSON.parse(adm.permissions_json) : adm.permissions_json;
      if (perms?.super_admin) {
        count++;
      }
    } catch (_) {}
  }
  return count;
}

// All admin management routes require SUPER_ADMIN authority
router.use(authenticateToken, authorizeSuperAdmin);

// 1. GET /api/admins — List and search administrators
router.get('/', (req, res) => {
  const { search, status } = req.query;

  let sql = `
    SELECT 
      u.id, 
      u.name, 
      u.email, 
      u.phone, 
      u.phone_verified, 
      u.role, 
      u.status, 
      u.is_active, 
      u.google_uid, 
      u.last_login_at, 
      u.created_at,
      ap.id as profile_id,
      ap.admin_id_number,
      ap.designation,
      ap.permissions_json,
      ap.created_by,
      creator.name as created_by_name
    FROM users u
    JOIN admin_profiles ap ON u.id = ap.user_id
    LEFT JOIN users creator ON ap.created_by = creator.id
    WHERE u.role IN ('admin', 'super_admin')
  `;

  const params = [];

  if (status) {
    sql += ' AND u.status = ?';
    params.push(status);
  }

  if (search && search.trim()) {
    const s = `%${search.trim().toLowerCase()}%`;
    sql += ' AND (LOWER(u.name) LIKE ? OR LOWER(u.email) LIKE ? OR LOWER(ap.admin_id_number) LIKE ? OR u.phone LIKE ?)';
    params.push(s, s, s, s);
  }

  sql += ' ORDER BY ap.admin_id_number ASC, u.created_at DESC';

  const rawAdmins = query(sql, params);
  const admins = rawAdmins.map(adm => {
    let permissions = {};
    try {
      permissions = typeof adm.permissions_json === 'string'
        ? JSON.parse(adm.permissions_json)
        : (adm.permissions_json || {});
    } catch (_) {}

    return {
      id: adm.id,
      name: adm.name,
      email: adm.email,
      phone: adm.phone,
      phone_verified: Boolean(adm.phone_verified),
      role: adm.role,
      status: adm.status,
      is_active: Boolean(adm.is_active),
      is_super_admin: adm.role === 'super_admin' || Boolean(permissions.super_admin),
      google_linked: Boolean(adm.google_uid),
      google_uid: adm.google_uid,
      admin_id_number: adm.admin_id_number || `ADM-2027-${adm.id.slice(-5)}`,
      designation: adm.designation,
      permissions,
      created_by: adm.created_by,
      created_by_name: adm.created_by_name,
      last_login_at: adm.last_login_at,
      created_at: adm.created_at
    };
  });

  res.json({
    success: true,
    data: admins,
    total: admins.length
  });
});

// 2. GET /api/admins/:id — View single admin details and activity
router.get('/:id', (req, res) => {
  const { id } = req.params;

  const adm = get(`
    SELECT 
      u.id, 
      u.name, 
      u.email, 
      u.phone, 
      u.phone_verified, 
      u.role, 
      u.status, 
      u.is_active, 
      u.google_uid, 
      u.last_login_at, 
      u.created_at,
      ap.id as profile_id,
      ap.admin_id_number,
      ap.designation,
      ap.permissions_json,
      ap.created_by,
      creator.name as created_by_name
    FROM users u
    JOIN admin_profiles ap ON u.id = ap.user_id
    LEFT JOIN users creator ON ap.created_by = creator.id
    WHERE u.id = ? AND u.role IN ('admin', 'super_admin')
  `, [id]);

  if (!adm) {
    return res.status(404).json({ success: false, error: 'Administrator account not found.' });
  }

  let permissions = {};
  try {
    permissions = typeof adm.permissions_json === 'string'
      ? JSON.parse(adm.permissions_json)
      : (adm.permissions_json || {});
  } catch (_) {}

  // Fetch recent audit logs relating to this admin
  const auditLogs = query(`
    SELECT id, user_id, action, entity_type, entity_id, details_json, created_at
    FROM audit_logs
    WHERE user_id = ? OR (entity_type = 'users' AND entity_id = ?)
    ORDER BY created_at DESC
    LIMIT 20
  `, [id, id]).map(log => {
    try {
      log.details = typeof log.details_json === 'string' ? JSON.parse(log.details_json) : log.details_json;
    } catch (_) {
      log.details = {};
    }
    return log;
  });

  res.json({
    success: true,
    data: {
      id: adm.id,
      name: adm.name,
      email: adm.email,
      phone: adm.phone,
      phone_verified: Boolean(adm.phone_verified),
      role: adm.role,
      status: adm.status,
      is_active: Boolean(adm.is_active),
      is_super_admin: adm.role === 'super_admin' || Boolean(permissions.super_admin),
      google_linked: Boolean(adm.google_uid),
      google_uid: adm.google_uid,
      admin_id_number: adm.admin_id_number,
      designation: adm.designation,
      permissions,
      created_by: adm.created_by,
      created_by_name: adm.created_by_name,
      last_login_at: adm.last_login_at,
      created_at: adm.created_at,
      auditLogs
    }
  });
});

// 3. POST /api/admins — Create a new Administrator (Super Admin only)
router.post('/', (req, res) => {
  const {
    name,
    email,
    password,
    phone,
    designation = 'Academic Administrator',
    permissions,
    admin_id_number,
    is_super_admin = false
  } = req.body;

  if (!name || !email || !password) {
    return res.status(400).json({
      success: false,
      error: 'Name, email, and temporary password are required to create an Administrator account.'
    });
  }

  const cleanEmail = email.trim().toLowerCase();
  const existing = get('SELECT id FROM users WHERE email = ?', [cleanEmail]);
  if (existing) {
    return res.status(400).json({
      success: false,
      error: 'An account with this email address already exists in the institutional registry.'
    });
  }

  // Auto-generate or validate unique Admin ID
  const finalAdminId = (admin_id_number && admin_id_number.trim())
    ? admin_id_number.trim().toUpperCase()
    : generateUniqueAdminId();

  const idCollision = get('SELECT id FROM admin_profiles WHERE admin_id_number = ?', [finalAdminId]);
  if (idCollision) {
    return res.status(409).json({
      success: false,
      error: `Admin ID "${finalAdminId}" is already assigned to another staff member.`
    });
  }

  // Default permissions if not provided
  const permsObj = typeof permissions === 'object' && permissions !== null
    ? { ...permissions }
    : {
        MANAGE_STUDENTS: true,
        MANAGE_MATERIALS: true,
        MANAGE_ASSIGNMENTS: true,
        MANAGE_NOTICES: true
      };

  if (is_super_admin) {
    permsObj.super_admin = true;
    permsObj.all = true;
  }

  const userId = 'user-adm-' + Date.now();
  const profileId = 'adm-prof-' + Date.now();
  const passwordHash = bcrypt.hashSync(password, 10);
  const permissionsJson = JSON.stringify(permsObj);

  const assignedRole = (is_super_admin || permsObj.super_admin) ? 'super_admin' : 'admin';

  transaction(() => {
    run(
      `INSERT INTO users (id, email, password_hash, role, name, phone, phone_verified, status, is_active)
       VALUES (?, ?, ?, ?, ?, ?, 0, 'active', 1)`,
      [userId, cleanEmail, passwordHash, assignedRole, name, phone || null]
    );

    run(
      `INSERT INTO admin_profiles (id, user_id, admin_id_number, designation, permissions_json, created_by)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [profileId, userId, finalAdminId, designation, permissionsJson, req.user.id]
    );
  });

  logAudit(req.user.id, 'CREATE_ADMIN', 'users', userId, {
    name,
    email: cleanEmail,
    admin_id_number: finalAdminId,
    designation,
    is_super_admin
  }, req);

  res.status(201).json({
    success: true,
    message: 'Administrator provisioned successfully.',
    id: userId,
    adminIdNumber: finalAdminId,
    data: {
      id: userId,
      admin_id_number: finalAdminId,
      name,
      email: cleanEmail,
      designation,
      status: 'active'
    }
  });
});

// 4. PUT /api/admins/:id — Edit Administrator profile and permissions
router.put('/:id', (req, res) => {
  const { id } = req.params;
  const { name, phone, designation, permissions, is_super_admin } = req.body;

  const user = get('SELECT id, name, email, role, status FROM users WHERE id = ? AND role IN (\'admin\', \'super_admin\')', [id]);
  if (!user) {
    return res.status(404).json({ success: false, error: 'Administrator account not found.' });
  }

  const profile = get('SELECT * FROM admin_profiles WHERE user_id = ?', [id]);
  if (!profile) {
    return res.status(404).json({ success: false, error: 'Admin profile record not found.' });
  }

  // Super Admin protection: Cannot demote the last super admin
  if (isSuperAdminUser(id) && is_super_admin === false) {
    const activeSuperCount = countActiveSuperAdmins();
    if (activeSuperCount <= 1) {
      return res.status(400).json({
        success: false,
        error: 'Safety restriction: Cannot remove Super Admin privileges from the only remaining active Super Administrator.'
      });
    }
  }

  let updatedPerms = null;
  if (permissions !== undefined || is_super_admin !== undefined) {
    let existingPerms = {};
    try {
      existingPerms = typeof profile.permissions_json === 'string' ? JSON.parse(profile.permissions_json) : profile.permissions_json;
    } catch (_) {}

    updatedPerms = { ...existingPerms, ...(permissions || {}) };
    if (is_super_admin === true) {
      updatedPerms.super_admin = true;
      updatedPerms.all = true;
    } else if (is_super_admin === false) {
      delete updatedPerms.super_admin;
      delete updatedPerms.all;
    }
  }

  transaction(() => {
    if (name || phone !== undefined || is_super_admin !== undefined) {
      const newRole = is_super_admin === true ? 'super_admin' : (is_super_admin === false ? 'admin' : null);
      run(
        "UPDATE users SET name = COALESCE(?, name), phone = COALESCE(?, phone), role = COALESCE(?, role), updated_at = datetime('now') WHERE id = ?",
        [name || null, phone !== undefined ? phone : null, newRole, id]
      );
    }

    if (designation || updatedPerms) {
      run(
        "UPDATE admin_profiles SET designation = COALESCE(?, designation), permissions_json = COALESCE(?, permissions_json), updated_at = datetime('now') WHERE user_id = ?",
        [designation || null, updatedPerms ? JSON.stringify(updatedPerms) : null, id]
      );
    }
  });

  logAudit(req.user.id, 'UPDATE_ADMIN', 'users', id, {
    name,
    phone,
    designation,
    permissionsUpdated: Boolean(updatedPerms)
  }, req);

  res.json({
    success: true,
    message: 'Administrator profile updated successfully.'
  });
});

// 5. POST /api/admins/:id/suspend — Suspend Administrator
router.post('/:id/suspend', (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  const targetAdmin = get('SELECT id, name, email, role, status FROM users WHERE id = ? AND role IN (\'admin\', \'super_admin\')', [id]);
  if (!targetAdmin) {
    return res.status(404).json({ success: false, error: 'Administrator account not found.' });
  }

  // Prevent self-suspension
  if (req.user.id === targetAdmin.id) {
    return res.status(400).json({
      success: false,
      error: 'Self-operation prohibited: Super Administrators cannot suspend their own account.'
    });
  }

  // Prevent suspending the only remaining active super admin
  if (isSuperAdminUser(id)) {
    const activeCount = countActiveSuperAdmins();
    if (activeCount <= 1) {
      return res.status(400).json({
        success: false,
        error: 'Safety restriction: Cannot suspend the only remaining active Super Administrator.'
      });
    }
  }

  run("UPDATE users SET status = 'suspended', is_active = 0, updated_at = datetime('now') WHERE id = ?", [id]);

  logAudit(req.user.id, 'SUSPEND_ADMIN', 'users', id, {
    targetName: targetAdmin.name,
    targetEmail: targetAdmin.email,
    reason: reason || 'Administrative suspension'
  }, req);

  res.json({
    success: true,
    message: `Administrator "${targetAdmin.name}" has been suspended.`
  });
});

// 6. POST /api/admins/:id/restore — Restore suspended or archived Administrator
router.post('/:id/restore', (req, res) => {
  const { id } = req.params;

  const targetAdmin = get('SELECT id, name, email, role, status FROM users WHERE id = ? AND role IN (\'admin\', \'super_admin\')', [id]);
  if (!targetAdmin) {
    return res.status(404).json({ success: false, error: 'Administrator account not found.' });
  }

  run("UPDATE users SET status = 'active', is_active = 1, updated_at = datetime('now') WHERE id = ?", [id]);

  logAudit(req.user.id, 'RESTORE_ADMIN', 'users', id, {
    targetName: targetAdmin.name,
    targetEmail: targetAdmin.email
  }, req);

  res.json({
    success: true,
    message: `Administrator "${targetAdmin.name}" has been restored to active status.`
  });
});

// 7. POST /api/admins/:id/archive — Archive Administrator (Controlled soft-removal)
router.post('/:id/archive', (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;

  const targetAdmin = get('SELECT id, name, email, role, status FROM users WHERE id = ? AND role IN (\'admin\', \'super_admin\')', [id]);
  if (!targetAdmin) {
    return res.status(404).json({ success: false, error: 'Administrator account not found.' });
  }

  // Prevent self-archival
  if (req.user.id === targetAdmin.id) {
    return res.status(400).json({
      success: false,
      error: 'Self-operation prohibited: Super Administrators cannot archive their own account.'
    });
  }

  // Prevent archiving the only remaining active super admin
  if (isSuperAdminUser(id)) {
    const activeCount = countActiveSuperAdmins();
    if (activeCount <= 1) {
      return res.status(400).json({
        success: false,
        error: 'Safety restriction: Cannot archive the only remaining active Super Administrator.'
      });
    }
  }

  run("UPDATE users SET status = 'archived', is_active = 0, updated_at = datetime('now') WHERE id = ?", [id]);

  logAudit(req.user.id, 'ARCHIVE_ADMIN', 'users', id, {
    targetName: targetAdmin.name,
    targetEmail: targetAdmin.email,
    reason: reason || 'Administrative removal / archiving'
  }, req);

  res.json({
    success: true,
    message: `Administrator "${targetAdmin.name}" has been archived. Access is restricted and records preserved.`
  });
});

// 8. GET /api/admins/:id/audit — View specific Admin audit history
router.get('/:id/audit', (req, res) => {
  const { id } = req.params;

  const auditLogs = query(`
    SELECT a.*, actor.name as actor_name, actor.role as actor_role
    FROM audit_logs a
    LEFT JOIN users actor ON a.user_id = actor.id
    WHERE a.user_id = ? OR (a.entity_type = 'users' AND a.entity_id = ?)
    ORDER BY a.created_at DESC
    LIMIT 50
  `, [id, id]).map(log => {
    try {
      log.details = typeof log.details_json === 'string' ? JSON.parse(log.details_json) : log.details_json;
    } catch (_) {
      log.details = {};
    }
    return log;
  });

  res.json({
    success: true,
    data: auditLogs
  });
});

module.exports = router;
