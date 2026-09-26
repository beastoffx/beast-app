const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('../config');
const { get, run, query, transaction } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { logAudit } = require('../middleware/audit');
const GoogleAuthService = require('../services/googleAuthService');
const { EmailService } = require('../services/emailService');

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

  if (!user.is_active || user.status === 'suspended' || user.status === 'archived' || user.status === 'expired') {
    return res.status(403).json({
      success: false,
      error: user.status === 'archived'
        ? 'This account has been archived. Access is disabled.'
        : user.status === 'suspended'
        ? 'This account has been suspended. Please contact administration.'
        : 'This account has been deactivated. Please contact administration.'
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
  } else if (user.role === 'admin' || user.role === 'super_admin') {
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
  } else if (user.role === 'admin' || user.role === 'super_admin') {
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
  run("UPDATE users SET password_hash = ?, updated_at = datetime('now') WHERE id = ?", [newHash, req.user.id]);

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

// Helper: Fetch role profile with full academic details
function fetchUserProfile(user) {
  if (user.role === 'student') {
    return get(
      `SELECT sp.*, c.name as class_name, b.name as batch_name, s.name as session_name
       FROM student_profiles sp
       LEFT JOIN classes c ON sp.class_id = c.id
       LEFT JOIN batches b ON sp.batch_id = b.id
       LEFT JOIN academic_sessions s ON sp.academic_session_id = s.id
       WHERE sp.user_id = ?`,
      [user.id]
    );
  } else if (user.role === 'teacher') {
    return get('SELECT * FROM teacher_profiles WHERE user_id = ?', [user.id]);
  } else if (user.role === 'admin' || user.role === 'super_admin') {
    return get('SELECT * FROM admin_profiles WHERE user_id = ?', [user.id]);
  }
  return null;
}

// POST /api/auth/google
// Primary authentication mechanism for Google Sign-In
router.post('/google', async (req, res) => {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      return res.status(400).json({
        success: false,
        error: 'Google identity token (idToken) is required.'
      });
    }

    const verification = await GoogleAuthService.verifyIdToken(idToken);
    if (!verification.valid) {
      return res.status(401).json({
        success: false,
        error: verification.error || 'Invalid Google identity token.'
      });
    }

    const { googleUid, email, name, picture } = verification;

    // 1. Check whether googleUid is already linked to an existing account
    const user = get(
      `SELECT id, google_uid, email, role, name, phone, phone_verified, status, avatar_url, is_active 
       FROM users WHERE google_uid = ?`,
      [googleUid]
    );

    if (user) {
      // Returning student/user on any device: verify authorization
      if (!user.is_active || user.status === 'suspended' || user.status === 'archived') {
        return res.status(403).json({
          success: false,
          error: user.status === 'archived'
            ? 'Your account has been archived. Access is disabled.'
            : 'Your account has been suspended by administration. Please contact support.'
        });
      }

      if (user.status === 'expired') {
        return res.status(403).json({
          success: false,
          error: 'Your institutional access period has expired. Please contact administration.'
        });
      }

      // Record successful login
      run("UPDATE users SET last_login_at = datetime('now'), updated_at = datetime('now') WHERE id = ?", [user.id]);

      const token = jwt.sign(
        { id: user.id, email: user.email, role: user.role, name: user.name, googleUid: user.google_uid },
        config.jwtSecret,
        { expiresIn: config.jwtExpiresIn }
      );

      const profile = fetchUserProfile(user);
      logAudit(user.id, 'GOOGLE_LOGIN_SUCCESS', 'users', user.id, { role: user.role, googleUid }, req);

      return res.json({
        success: true,
        status: 'LINKED',
        token,
        user: {
          id: user.id,
          google_uid: user.google_uid,
          email: user.email,
          role: user.role,
          name: user.name,
          phone: user.phone,
          phone_verified: Boolean(user.phone_verified),
          status: user.status,
          avatar_url: user.avatar_url || picture
        },
        profile
      });
    }

    // 2. Account is not linked by google_uid. Check if pre-provisioned staff matches email
    const facultyUser = get(
      `SELECT * FROM users WHERE email = ? AND role IN ('admin', 'teacher', 'super_admin') AND (google_uid IS NULL OR google_uid = '')`,
      [email]
    );
    if (facultyUser) {
      if (!facultyUser.is_active || facultyUser.status === 'suspended' || facultyUser.status === 'archived') {
        return res.status(403).json({
          success: false,
          error: facultyUser.status === 'archived'
            ? 'Your account has been archived. Access is disabled.'
            : 'Your account has been suspended by administration. Please contact support.'
        });
      }

      run("UPDATE users SET google_uid = ?, updated_at = datetime('now'), last_login_at = datetime('now') WHERE id = ?", [googleUid, facultyUser.id]);
      const token = jwt.sign(
        { id: facultyUser.id, email: facultyUser.email, role: facultyUser.role, name: facultyUser.name, googleUid },
        config.jwtSecret,
        { expiresIn: config.jwtExpiresIn }
      );
      const profile = fetchUserProfile(facultyUser);
      logAudit(facultyUser.id, 'FACULTY_GOOGLE_LINKED', 'users', facultyUser.id, { googleUid }, req);

      return res.json({
        success: true,
        status: 'LINKED',
        token,
        user: {
          id: facultyUser.id,
          google_uid: googleUid,
          email: facultyUser.email,
          role: facultyUser.role,
          name: facultyUser.name,
          phone: facultyUser.phone,
          status: facultyUser.status,
          avatar_url: facultyUser.avatar_url || picture
        },
        profile
      });
    }

    // 3. Unlinked Google Account: requires institute Student ID activation
    return res.json({
      success: true,
      status: 'UNLINKED',
      googleUid,
      email,
      name,
      picture,
      message: 'This Google account is not yet linked to an authorized B.E.A.S.T Academy Student ID. Please complete activation.'
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: 'Google authentication error: ' + err.message });
  }
});

// ==================== STUDENT IDENTITY VALIDATION & CONFIRMATION ====================
// POST /api/auth/activate/student
// Validates official Student ID and returns safe confirmation identity data (no sensitive leaks)
async function handleValidateStudent(req, res) {
  try {
    const { studentIdNumber, googleUid } = req.body;

    if (!studentIdNumber) {
      return res.status(400).json({
        success: false,
        error: 'Official Institute Student ID number is required.'
      });
    }

    const cleanStudentId = studentIdNumber.trim().toUpperCase();

    // Verify Student ID in institutional registry
    const studentProfile = get(
      `SELECT sp.*, u.id as user_id, u.name, u.email, u.google_uid, u.status, u.is_active, u.role,
              c.name as class_name, b.name as batch_name
       FROM student_profiles sp
       JOIN users u ON sp.user_id = u.id
       LEFT JOIN classes c ON sp.class_id = c.id
       LEFT JOIN batches b ON sp.batch_id = b.id
       WHERE sp.student_id_number = ?`,
      [cleanStudentId]
    );

    if (!studentProfile || studentProfile.role !== 'student') {
      return res.status(404).json({
        success: false,
        error: 'Invalid Student ID. Please ensure you enter your official institute-issued Student ID (e.g. BST-2027-00001).'
      });
    }

    if (studentProfile.status === 'archived') {
      return res.status(403).json({
        success: false,
        error: 'This student account has been archived. Access is disabled.'
      });
    }

    if (!studentProfile.is_active || studentProfile.status === 'suspended') {
      return res.status(403).json({
        success: false,
        error: 'This student account has been suspended. Please contact institute administration.'
      });
    }

    // Verify trusted institutional email exists
    if (!studentProfile.email || !studentProfile.email.trim() || !studentProfile.email.includes('@')) {
      return res.status(400).json({
        success: false,
        error: 'EMAIL_NOT_CONFIGURED',
        message: 'No registered institutional email address found for this Student ID. Please contact administration.'
      });
    }

    // Check if student ID is already linked to another Google account
    if (studentProfile.google_uid && (!googleUid || studentProfile.google_uid !== googleUid)) {
      return res.status(409).json({
        success: false,
        error: 'This Student ID is already linked to another Google account. Please contact institute administration.'
      });
    }

    // Check if the Google account is already linked to another student or staff
    if (googleUid) {
      const existingGoogle = get('SELECT id FROM users WHERE google_uid = ? AND id != ?', [googleUid, studentProfile.user_id]);
      if (existingGoogle) {
        return res.status(409).json({
          success: false,
          error: 'This Google account is already linked to another institutional identity.'
        });
      }
    }

    // Return safe confirmation details with masked email
    return res.json({
      success: true,
      eligible: true,
      studentIdNumber: studentProfile.student_id_number,
      name: studentProfile.name,
      className: studentProfile.class_name || 'Enrolled Program',
      batchName: studentProfile.batch_name || 'Assigned Batch',
      emailMasked: EmailService.maskEmail(studentProfile.email),
      message: 'Student ID validated. Verification code will be dispatched to your registered institute email.'
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

// POST /api/auth/email-otp/request and /api/auth/activate/send-otp
// Dispatches verification code via EmailService to the trusted student email
async function handleSendEmailOtp(req, res) {
  try {
    const { googleUid, studentIdNumber } = req.body;

    if (!googleUid || !studentIdNumber) {
      return res.status(400).json({
        success: false,
        error: 'Google UID and Student ID number are required.'
      });
    }

    const cleanStudentId = studentIdNumber.trim().toUpperCase();

    // Verify Student ID exists and belongs to a student
    const studentProfile = get(
      `SELECT sp.*, u.id as user_id, u.name, u.email, u.google_uid, u.status, u.is_active, u.role 
       FROM student_profiles sp
       JOIN users u ON sp.user_id = u.id
       WHERE sp.student_id_number = ?`,
      [cleanStudentId]
    );

    if (!studentProfile || studentProfile.role !== 'student') {
      return res.status(404).json({
        success: false,
        error: 'Invalid Student ID. Please ensure you enter your official institute-issued Student ID (e.g. BST-2027-00001).'
      });
    }

    // Check account status
    if (!studentProfile.is_active || studentProfile.status === 'suspended' || studentProfile.status === 'archived') {
      return res.status(403).json({
        success: false,
        error: studentProfile.status === 'archived'
          ? 'This student account has been archived. Access is disabled.'
          : 'This student account has been suspended. Please contact institute administration.'
      });
    }

    // Verify trusted institutional email exists
    if (!studentProfile.email || !studentProfile.email.trim() || !studentProfile.email.includes('@')) {
      return res.status(400).json({
        success: false,
        error: 'EMAIL_NOT_CONFIGURED',
        message: 'No registered institutional email address found for this Student ID. Please contact administration.'
      });
    }

    // Check if student ID is already linked to another Google account
    if (studentProfile.google_uid && studentProfile.google_uid !== googleUid) {
      return res.status(409).json({
        success: false,
        error: 'This Student ID is already linked to another Google account. Please contact institute administration.'
      });
    }

    // Check if another user already holds this googleUid
    const existingGoogle = get('SELECT id FROM users WHERE google_uid = ? AND id != ?', [googleUid, studentProfile.user_id]);
    if (existingGoogle) {
      return res.status(409).json({
        success: false,
        error: 'This Google account is already linked to another institutional identity.'
      });
    }

    // Rate-limiting: prevent spamming multiple requests within 60 seconds
    const recentOtp = get(
      `SELECT created_at FROM email_verifications 
       WHERE student_id_number = ? AND created_at > datetime('now', '-60 seconds')
       ORDER BY created_at DESC LIMIT 1`,
      [cleanStudentId]
    );
    if (recentOtp && config.nodeEnv !== 'test') {
      return res.status(429).json({
        success: false,
        error: 'Please wait 60 seconds before requesting another verification code.'
      });
    }

    // Dispatch verification code via EmailService to the trusted student email
    const otpResult = await EmailService.initiateVerification({
      studentIdNumber: cleanStudentId,
      googleUid
    });

    if (!otpResult.success) {
      if (otpResult.code === 'EMAIL_NOT_CONFIGURED') {
        return res.status(400).json({
          success: false,
          error: 'EMAIL_NOT_CONFIGURED',
          message: otpResult.error
        });
      }
      return res.status(500).json({
        success: false,
        error: otpResult.error || 'Failed to dispatch verification code.'
      });
    }

    logAudit(studentProfile.user_id, 'EMAIL_OTP_DISPATCHED', 'email_verifications', otpResult.sessionId, { studentIdNumber: cleanStudentId }, req);

    return res.json({
      success: true,
      sessionId: otpResult.sessionId,
      message: 'Verification code successfully sent to registered institute email.',
      emailMasked: otpResult.emailMasked,
      expiresAt: otpResult.expiresAt
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
}

// POST /api/auth/email-otp/verify and /api/auth/activate/verify
// Step 2: Validates Email OTP, atomically links Google UID + Student ID, activates account, and returns session
async function handleVerifyEmailOtp(req, res) {
  try {
    const { sessionId, otp, googleUid, studentIdNumber } = req.body;

    if (!sessionId || !otp || !googleUid || !studentIdNumber) {
      return res.status(400).json({
        success: false,
        error: 'Session ID, OTP code, Google UID, and Student ID number are required.'
      });
    }

    const cleanStudentId = studentIdNumber.trim().toUpperCase();

    // Verify OTP code
    const verification = EmailService.verifyOtp({
      sessionId,
      otpCode: otp,
      studentIdNumber: cleanStudentId,
      googleUid
    });

    if (!verification.success) {
      return res.status(400).json({
        success: false,
        error: verification.error
      });
    }

    // Verify student user record
    const studentProfile = get(
      `SELECT sp.*, u.id as user_id, u.name, u.email, u.google_uid, u.status, u.is_active, u.role 
       FROM student_profiles sp
       JOIN users u ON sp.user_id = u.id
       WHERE sp.student_id_number = ?`,
      [cleanStudentId]
    );

    if (!studentProfile || studentProfile.role !== 'student') {
      return res.status(404).json({ success: false, error: 'Student record not found.' });
    }

    if (!studentProfile.is_active || studentProfile.status === 'suspended' || studentProfile.status === 'archived') {
      return res.status(403).json({
        success: false,
        error: studentProfile.status === 'archived'
          ? 'This student account has been archived. Access is disabled.'
          : 'This student account has been suspended. Please contact institute administration.'
      });
    }

    // Transactional atomic account linking and activation
    transaction(() => {
      // Re-verify uniqueness inside transaction to prevent race conditions
      const existingGoogle = get('SELECT id FROM users WHERE google_uid = ? AND id != ?', [googleUid, studentProfile.user_id]);
      if (existingGoogle) {
        throw new Error('This Google account is already linked to another institutional user.');
      }

      const currentStudent = get('SELECT u.id, u.google_uid FROM users u JOIN student_profiles sp ON u.id = sp.user_id WHERE sp.student_id_number = ?', [cleanStudentId]);
      if (currentStudent && currentStudent.google_uid && currentStudent.google_uid !== googleUid) {
        throw new Error('This Student ID is already linked to another Google account.');
      }

      run(
        `UPDATE users 
         SET google_uid = ?, status = 'active', is_active = 1, updated_at = datetime('now'), last_login_at = datetime('now')
         WHERE id = ?`,
        [googleUid, studentProfile.user_id]
      );
    });

    const updatedUser = get('SELECT id, google_uid, email, role, name, phone, status, is_active FROM users WHERE id = ?', [studentProfile.user_id]);
    const profile = fetchUserProfile(updatedUser);

    const token = jwt.sign(
      { id: updatedUser.id, email: updatedUser.email, role: updatedUser.role, name: updatedUser.name, googleUid: updatedUser.google_uid },
      config.jwtSecret,
      { expiresIn: config.jwtExpiresIn }
    );

    logAudit(updatedUser.id, 'STUDENT_ACTIVATED', 'users', updatedUser.id, { studentIdNumber: cleanStudentId, email: verification.email, googleUid }, req);

    return res.json({
      success: true,
      status: 'ACTIVATED',
      token,
      user: {
        id: updatedUser.id,
        google_uid: updatedUser.google_uid,
        email: updatedUser.email,
        role: updatedUser.role,
        name: updatedUser.name,
        phone: updatedUser.phone,
        status: updatedUser.status
      },
      profile,
      message: 'Student account successfully activated and linked to Google account.'
    });
  } catch (err) {
    if (err.message.includes('already linked')) {
      return res.status(409).json({ success: false, error: err.message });
    }
    return res.status(500).json({ success: false, error: err.message });
  }
}

// Router mounts: Official Email OTP Endpoints
router.post('/activate/student', (req, res) => {
  if (req.body.otp || req.body.sessionId) {
    return handleVerifyEmailOtp(req, res);
  }
  return handleValidateStudent(req, res);
});

router.post('/email-otp/request', handleSendEmailOtp);
router.post('/email-otp/verify', handleVerifyEmailOtp);

// Backward-compatible activation route aliases
router.post('/activate/send-otp', handleSendEmailOtp);
router.post('/activate/verify', handleVerifyEmailOtp);

// Explicitly disabled/deprecated phone OTP endpoints
router.post('/phone/send-otp', (req, res) => {
  return res.status(410).json({
    success: false,
    error: 'Phone OTP verification has been removed. Please use email verification.'
  });
});

router.post('/phone/verify-otp', (req, res) => {
  return res.status(410).json({
    success: false,
    error: 'Phone OTP verification has been removed. Please use email verification.'
  });
});

module.exports = router;
