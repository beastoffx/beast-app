const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('../config');
const { get, run, query } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { logAudit } = require('../middleware/audit');

const router = express.Router();

// POST /api/auth/login
router.post('/login', (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      success: false,
      error: 'Email and password are required.'
    });
  }

  const cleanEmail = email.trim().toLowerCase();
  const user = get('SELECT * FROM users WHERE email = ?', [cleanEmail]);

  if (!user) {
    return res.status(401).json({
      success: false,
      error: 'Invalid credentials. Please check your email and password.'
    });
  }

  if (!user.is_active) {
    return res.status(403).json({
      success: false,
      error: 'This account has been deactivated. Please contact administration.'
    });
  }

  const isPasswordValid = bcrypt.compareSync(password, user.password_hash);
  if (!isPasswordValid) {
    return res.status(401).json({
      success: false,
      error: 'Invalid credentials. Please check your email and password.'
    });
  }

  // Generate secure JWT
  const tokenPayload = {
    id: user.id,
    email: user.email,
    role: user.role,
    name: user.name
  };

  const token = jwt.sign(tokenPayload, config.jwtSecret, { expiresIn: config.jwtExpiresIn });

  // Fetch role-specific profile details
  let profile = null;
  if (user.role === 'student') {
    profile = get(
      `SELECT sp.*, c.name as class_name, b.name as batch_name, s.name as session_name
       FROM student_profiles sp
       LEFT JOIN classes c ON sp.class_id = c.id
       LEFT JOIN batches b ON sp.batch_id = b.id
       LEFT JOIN academic_sessions s ON sp.academic_session_id = s.id
       WHERE sp.user_id = ?`,
      [user.id]
    );
  } else if (user.role === 'teacher') {
    profile = get('SELECT * FROM teacher_profiles WHERE user_id = ?', [user.id]);
  } else if (user.role === 'admin') {
    profile = get('SELECT * FROM admin_profiles WHERE user_id = ?', [user.id]);
  }

  logAudit(user.id, 'USER_LOGIN', 'users', user.id, { role: user.role }, req);

  // Return clean user object (never leak password hash)
  const safeUser = {
    id: user.id,
    email: user.email,
    role: user.role,
    name: user.name,
    phone: user.phone,
    avatar_url: user.avatar_url
  };

  res.json({
    success: true,
    token,
    user: safeUser,
    profile
  });
});

// GET /api/auth/me
router.get('/me', authenticateToken, (req, res) => {
  const user = req.user;
  let profile = null;

  if (user.role === 'student') {
    profile = get(
      `SELECT sp.*, c.name as class_name, b.name as batch_name, s.name as session_name
       FROM student_profiles sp
       LEFT JOIN classes c ON sp.class_id = c.id
       LEFT JOIN batches b ON sp.batch_id = b.id
       LEFT JOIN academic_sessions s ON sp.academic_session_id = s.id
       WHERE sp.user_id = ?`,
      [user.id]
    );
  } else if (user.role === 'teacher') {
    profile = get('SELECT * FROM teacher_profiles WHERE user_id = ?', [user.id]);
  } else if (user.role === 'admin') {
    profile = get('SELECT * FROM admin_profiles WHERE user_id = ?', [user.id]);
  }

  res.json({
    success: true,
    user,
    profile
  });
});

// POST /api/auth/change-password
router.post('/change-password', authenticateToken, (req, res) => {
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({
      success: false,
      error: 'Current and new password are required.'
    });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({
      success: false,
      error: 'New password must be at least 6 characters long.'
    });
  }

  const user = get('SELECT * FROM users WHERE id = ?', [req.user.id]);
  if (!bcrypt.compareSync(currentPassword, user.password_hash)) {
    return res.status(400).json({
      success: false,
      error: 'Incorrect current password.'
    });
  }

  const newHash = bcrypt.hashSync(newPassword, 10);
  run('UPDATE users SET password_hash = ?, updated_at = datetime("now") WHERE id = ?', [newHash, req.user.id]);

  logAudit(req.user.id, 'CHANGE_PASSWORD', 'users', req.user.id, {}, req);

  res.json({
    success: true,
    message: 'Password changed successfully.'
  });
});

// POST /api/auth/recover-request
router.post('/recover-request', (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ success: false, error: 'Email is required.' });
  }

  const user = get('SELECT id, email, role FROM users WHERE email = ?', [email.trim().toLowerCase()]);
  if (user) {
    logAudit(user.id, 'PASSWORD_RECOVERY_REQUEST', 'users', user.id, { email: user.email }, req);
  }

  // Consistent response to prevent user enumeration
  res.json({
    success: true,
    message: 'If an account exists with this email address, password reset instructions have been logged for administrative verification.'
  });
});

// POST /api/auth/logout
router.post('/logout', authenticateToken, (req, res) => {
  logAudit(req.user.id, 'USER_LOGOUT', 'users', req.user.id, {}, req);
  res.json({
    success: true,
    message: 'Logged out successfully.'
  });
});

module.exports = router;
