const jwt = require('jsonwebtoken');
const config = require('../config');
const { get } = require('../db');

async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'Access denied. No authentication token provided.'
    });
  }

  try {
    const decoded = jwt.verify(token, config.jwtSecret);
    // Fetch live user status to ensure account is not deactivated or suspended
    const user = await get(
      'SELECT id, google_uid, email, role, name, phone, phone_verified, status, is_active FROM users WHERE id = ?',
      [decoded.id]
    );

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid session. User no longer exists.'
      });
    }

    if (user.status === 'archived') {
      return res.status(403).json({
        success: false,
        error: 'Account has been archived. Access is disabled.'
      });
    }

    if (!user.is_active || user.status === 'suspended') {
      return res.status(403).json({
        success: false,
        error: 'Account has been suspended or deactivated. Please contact administration.'
      });
    }

    if (user.status === 'expired') {
      return res.status(403).json({
        success: false,
        error: 'Account access has expired. Please contact administration to renew.'
      });
    }

    // Determine base super admin privilege
    const isSuperAdminUser = user.role === 'super_admin';
    let effectiveRole = decoded.role || user.role;

    if (effectiveRole !== user.role && !isSuperAdminUser) {
      let eligible = false;
      if (effectiveRole === 'student') {
        const p = await get('SELECT id FROM student_profiles WHERE user_id = ?', [user.id]);
        if (p) eligible = true;
      } else if (effectiveRole === 'teacher') {
        const p = await get('SELECT id FROM teacher_profiles WHERE user_id = ?', [user.id]);
        if (p) eligible = true;
      } else if (effectiveRole === 'admin') {
        const p = await get('SELECT id FROM admin_profiles WHERE user_id = ?', [user.id]);
        if (p) eligible = true;
      }
      if (!eligible) {
        effectiveRole = user.role;
      }
    }

    user.role = effectiveRole;
    user.primary_role = isSuperAdminUser ? 'super_admin' : user.role;

    // Attach student subscription attributes if role is student
    if (user.role === 'student') {
      const studentProfile = await get(
        'SELECT subscription_status, access_start_date, access_end_date, resource_permissions_json FROM student_profiles WHERE user_id = ?',
        [user.id]
      );
      if (studentProfile) {
        user.subscription_status = studentProfile.subscription_status || 'paid';
        user.access_start_date = studentProfile.access_start_date;
        user.access_end_date = studentProfile.access_end_date;
        try {
          user.resource_permissions = typeof studentProfile.resource_permissions_json === 'string'
            ? JSON.parse(studentProfile.resource_permissions_json)
            : studentProfile.resource_permissions_json;
        } catch (_) {
          user.resource_permissions = { materials: true, doubts: true, exams: true };
        }
      } else if (isSuperAdminUser) {
        user.subscription_status = 'paid';
        user.resource_permissions = { materials: true, doubts: true, exams: true };
      }
    }

    // Attach admin profile & permissions if role is admin or super_admin
    if (user.role === 'admin' || user.role === 'super_admin' || isSuperAdminUser) {
      const adminProfile = await get(
        'SELECT designation, permissions_json, admin_id_number FROM admin_profiles WHERE user_id = ?',
        [user.id]
      );
      user.permissions = {};
      if (adminProfile) {
        user.designation = adminProfile.designation;
        user.admin_id_number = adminProfile.admin_id_number;
        try {
          user.permissions = typeof adminProfile.permissions_json === 'string'
            ? JSON.parse(adminProfile.permissions_json)
            : (adminProfile.permissions_json || {});
        } catch (_) {
          user.permissions = {};
        }
      }
      user.isSuperAdmin = isSuperAdminUser || user.role === 'super_admin' || Boolean(user.permissions?.super_admin);
    }

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Session has expired. Please log in again.'
      });
    }
    return res.status(401).json({
      success: false,
      error: 'Invalid authentication token.'
    });
  }
}

module.exports = { authenticateToken };
