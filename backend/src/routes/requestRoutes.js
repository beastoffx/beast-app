const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { query, get, run, transaction } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { authorizeRoles } = require('../middleware/rbac');
const { logAudit } = require('../middleware/audit');

// Collision-safe Student ID generator: BST-2027-XXXXX
async function generateUniqueStudentId(year = '2027') {
  let counter = 1;
  while (counter < 100000) {
    const candidate = `BST-${year}-${String(counter).padStart(5, '0')}`;
    const exists = await get('SELECT id FROM student_profiles WHERE student_id_number = ?', [candidate]);
    if (!exists) {
      return candidate;
    }
    counter++;
  }
  return `BST-${year}-${Date.now().toString().slice(-5)}`;
}

// Collision-safe Teacher Employee Code generator: TCH-2027-XXXXX
async function generateUniqueTeacherId(year = '2027') {
  let counter = 1;
  while (counter < 100000) {
    const candidate = `TCH-${year}-${String(counter).padStart(5, '0')}`;
    const exists = await get('SELECT id FROM teacher_profiles WHERE employee_code = ?', [candidate]);
    if (!exists) {
      return candidate;
    }
    counter++;
  }
  return `TCH-${year}-${Date.now().toString().slice(-5)}`;
}

// Collision-safe Admin ID generator: ADM-2027-XXXXX
async function generateUniqueAdminId(year = '2027') {
  let counter = 1;
  while (counter < 100000) {
    const candidate = `ADM-${year}-${String(counter).padStart(5, '0')}`;
    const exists = await get('SELECT id FROM admin_profiles WHERE admin_id_number = ?', [candidate]);
    if (!exists) {
      return candidate;
    }
    counter++;
  }
  return `ADM-${year}-${Date.now().toString().slice(-5)}`;
}

/**
 * GET /api/requests/meta
 * Public metadata for onboarding applications (classes, batches, sessions)
 */
router.get('/meta', async (req, res) => {
  try {
    const classes = await query('SELECT id, name, stream FROM classes ORDER BY name ASC');
    const batches = await query('SELECT id, name, class_id, academic_session_id FROM batches ORDER BY name ASC');
    const currentSession = await get('SELECT id, name FROM academic_sessions WHERE is_current = 1 LIMIT 1')
      || await get('SELECT id, name FROM academic_sessions ORDER BY start_date DESC LIMIT 1');
    res.json({
      success: true,
      data: {
        classes,
        batches,
        currentSession
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Internal server error fetching application metadata.' });
  }
});

/**
 * POST /api/requests
 * Submit a new onboarding application (Public)
 */
router.post('/', async (req, res) => {
  try {
    const {
      name,
      email,
      phone,
      google_uid,
      requested_role,
      target_class_id,
      target_batch_id,
      target_session_id,
      qualification,
      department,
      notes
    } = req.body;

    if (!name || !email || !requested_role) {
      return res.status(400).json({
        success: false,
        error: 'Name, email, and requested_role are required.'
      });
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanRole = requested_role.trim().toLowerCase();

    if (!['student', 'teacher', 'admin'].includes(cleanRole)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid requested_role. Allowed roles: student, teacher, admin.'
      });
    }

    // Check if user already exists
    const existingUser = await get('SELECT id, status, is_active FROM users WHERE email = ?', [cleanEmail]);
    if (existingUser && existingUser.is_active && existingUser.status === 'active') {
      return res.status(409).json({
        success: false,
        error: 'An active account already exists with this email address. Please sign in.'
      });
    }

    // Check for pending request
    const pendingRequest = await get(
      `SELECT id, status FROM account_requests 
       WHERE email = ? AND status IN ('PENDING_TEACHER_REVIEW', 'PENDING_ADMIN_REVIEW', 'PENDING_SUPER_ADMIN_REVIEW')`,
      [cleanEmail]
    );
    if (pendingRequest) {
      return res.status(409).json({
        success: false,
        error: 'An onboarding request is already pending review for this email address.',
        status: pendingRequest.status
      });
    }

    // Student specific validations
    if (cleanRole === 'student') {
      if (!target_class_id || !target_batch_id || !target_session_id) {
        return res.status(400).json({
          success: false,
          error: 'Students must provide target class, batch, and academic session.'
        });
      }
      const cls = await get('SELECT id FROM classes WHERE id = ?', [target_class_id]);
      const btc = await get('SELECT id FROM batches WHERE id = ?', [target_batch_id]);
      const ses = await get('SELECT id FROM academic_sessions WHERE id = ?', [target_session_id]);
      if (!cls || !btc || !ses) {
        return res.status(400).json({
          success: false,
          error: 'Invalid target class, batch, or session ID provided.'
        });
      }
    }

    // Determine initial status according to multi-tier approval rules:
    // - Student: starts at PENDING_TEACHER_REVIEW
    // - Teacher: starts at PENDING_ADMIN_REVIEW
    // - Admin: starts at PENDING_SUPER_ADMIN_REVIEW
    let initialStatus = 'PENDING_TEACHER_REVIEW';
    if (cleanRole === 'teacher') {
      initialStatus = 'PENDING_ADMIN_REVIEW';
    } else if (cleanRole === 'admin') {
      initialStatus = 'PENDING_SUPER_ADMIN_REVIEW';
    }

    const id = `req-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;

    await run(
      `INSERT INTO account_requests (
        id, email, name, phone, google_uid, requested_role, status,
        target_class_id, target_batch_id, target_session_id,
        qualification, department, notes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        cleanEmail,
        name.trim(),
        phone ? phone.trim() : null,
        google_uid ? google_uid.trim() : null,
        cleanRole,
        initialStatus,
        target_class_id || null,
        target_batch_id || null,
        target_session_id || null,
        qualification ? qualification.trim() : null,
        department ? department.trim() : null,
        notes ? notes.trim() : null
      ]
    );

    logAudit(null, 'ACCOUNT_REQUEST_SUBMITTED', 'account_requests', id, {
      email: cleanEmail,
      requested_role: cleanRole,
      status: initialStatus
    }, req);

    res.status(201).json({
      success: true,
      message: 'Your onboarding application has been submitted for institutional review.',
      data: {
        id,
        email: cleanEmail,
        name: name.trim(),
        requested_role: cleanRole,
        status: initialStatus
      }
    });
  } catch (err) {
    console.error('[REQUEST_SUBMIT_ERROR]', err);
    res.status(500).json({ success: false, error: 'Internal server error while submitting onboarding request.' });
  }
});

/**
 * GET /api/requests/status
 * Check application status by email or googleUid (Public)
 */
router.get('/status', async (req, res) => {
  try {
    const { email, googleUid } = req.query;
    if (!email && !googleUid) {
      return res.status(400).json({ success: false, error: 'email or googleUid query parameter is required.' });
    }

    let request = null;
    if (email) {
      request = await get(
        `SELECT ar.*, c.name as class_name, b.name as batch_name, s.name as session_name
         FROM account_requests ar
         LEFT JOIN classes c ON ar.target_class_id = c.id
         LEFT JOIN batches b ON ar.target_batch_id = b.id
         LEFT JOIN academic_sessions s ON ar.target_session_id = s.id
         WHERE ar.email = ?
         ORDER BY ar.created_at DESC LIMIT 1`,
        [email.trim().toLowerCase()]
      );
    } else if (googleUid) {
      request = await get(
        `SELECT ar.*, c.name as class_name, b.name as batch_name, s.name as session_name
         FROM account_requests ar
         LEFT JOIN classes c ON ar.target_class_id = c.id
         LEFT JOIN batches b ON ar.target_batch_id = b.id
         LEFT JOIN academic_sessions s ON ar.target_session_id = s.id
         WHERE ar.google_uid = ?
         ORDER BY ar.created_at DESC LIMIT 1`,
        [googleUid.trim()]
      );
    }

    res.json({
      success: true,
      data: request || null
    });
  } catch (err) {
    console.error('[REQUEST_STATUS_ERROR]', err);
    res.status(500).json({ success: false, error: 'Internal server error fetching status.' });
  }
});

/**
 * GET /api/requests
 * List pending onboarding applications for review (Protected: teacher, admin, super_admin)
 */
router.get('/', authenticateToken, authorizeRoles('teacher', 'admin', 'super_admin'), async (req, res) => {
  try {
    const { role } = req.user;
    const { status, limit = 50 } = req.query;

    let sql = `
      SELECT ar.*, c.name as class_name, b.name as batch_name, s.name as session_name
      FROM account_requests ar
      LEFT JOIN classes c ON ar.target_class_id = c.id
      LEFT JOIN batches b ON ar.target_batch_id = b.id
      LEFT JOIN academic_sessions s ON ar.target_session_id = s.id
    `;
    const params = [];
    const conditions = [];

    if (role === 'teacher') {
      // Teachers review student requests at stage 1
      conditions.push("ar.requested_role = 'student'");
      if (status) {
        conditions.push("ar.status = ?");
        params.push(status);
      } else {
        conditions.push("ar.status = 'PENDING_TEACHER_REVIEW'");
      }
    } else if (role === 'admin') {
      // Admins review requests at stage 2 (students approved by teachers, or teachers at stage 1)
      if (status) {
        conditions.push("ar.status = ?");
        params.push(status);
      } else {
        conditions.push("ar.status = 'PENDING_ADMIN_REVIEW'");
      }
    } else if (role === 'super_admin') {
      // Super Admin reviews final stage (stage 3 for students, stage 2 for teachers, stage 1 for admins)
      if (status) {
        conditions.push("ar.status = ?");
        params.push(status);
      } else {
        conditions.push("ar.status = 'PENDING_SUPER_ADMIN_REVIEW'");
      }
    }

    if (conditions.length > 0) {
      sql += ` WHERE ${conditions.join(' AND ')}`;
    }

    sql += ' ORDER BY ar.created_at DESC LIMIT ?';
    params.push(parseInt(limit, 10));

    const requests = await query(sql, params);

    res.json({
      success: true,
      data: requests,
      total: requests.length
    });
  } catch (err) {
    console.error('[REQUESTS_LIST_ERROR]', err);
    res.status(500).json({ success: false, error: 'Internal server error fetching requests.' });
  }
});

/**
 * POST /api/requests/:id/review
 * Multi-tier review action: approve or reject (Protected: teacher, admin, super_admin)
 */
router.post('/:id/review', authenticateToken, authorizeRoles('teacher', 'admin', 'super_admin'), async (req, res) => {
  try {
    const { id } = req.params;
    const { action, reviewNotes, rejectionReason } = req.body;
    const reviewerRole = req.user.role;
    const reviewerId = req.user.id;

    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid action. Must be "approve" or "reject".'
      });
    }

    const request = await get('SELECT * FROM account_requests WHERE id = ?', [id]);
    if (!request) {
      return res.status(404).json({ success: false, error: 'Account request not found.' });
    }

    if (request.status === 'APPROVED' || request.status === 'REJECTED') {
      return res.status(400).json({
        success: false,
        error: `This request has already been finalized as ${request.status}.`
      });
    }

    // Role stage verification
    if (reviewerRole === 'teacher') {
      if (request.status !== 'PENDING_TEACHER_REVIEW') {
        return res.status(403).json({
          success: false,
          error: 'Teachers can only review requests in PENDING_TEACHER_REVIEW status.'
        });
      }

      if (action === 'reject') {
        await run(
          `UPDATE account_requests 
           SET status = 'REJECTED',
               rejection_reason = ?,
               teacher_reviewer_id = ?,
               teacher_reviewed_at = datetime('now'),
               teacher_review_notes = ?,
               updated_at = datetime('now')
           WHERE id = ?`,
          [rejectionReason || 'Rejected by Teacher review.', reviewerId, reviewNotes || null, id]
        );
      } else {
        await run(
          `UPDATE account_requests 
           SET status = 'PENDING_ADMIN_REVIEW',
               teacher_reviewer_id = ?,
               teacher_reviewed_at = datetime('now'),
               teacher_review_notes = ?,
               updated_at = datetime('now')
           WHERE id = ?`,
          [reviewerId, reviewNotes || null, id]
        );
      }

      logAudit(reviewerId, `TEACHER_REVIEW_${action.toUpperCase()}`, 'account_requests', id, { action, reviewNotes }, req);

      const updated = await get('SELECT * FROM account_requests WHERE id = ?', [id]);
      return res.json({
        success: true,
        message: action === 'approve'
          ? 'Student request approved by Teacher and forwarded to Administration.'
          : 'Student request rejected.',
        data: updated
      });
    }

    if (reviewerRole === 'admin') {
      if (request.status !== 'PENDING_ADMIN_REVIEW') {
        return res.status(403).json({
          success: false,
          error: 'Administrators can only review requests in PENDING_ADMIN_REVIEW status.'
        });
      }

      if (action === 'reject') {
        await run(
          `UPDATE account_requests 
           SET status = 'REJECTED',
               rejection_reason = ?,
               admin_reviewer_id = ?,
               admin_reviewed_at = datetime('now'),
               admin_review_notes = ?,
               updated_at = datetime('now')
           WHERE id = ?`,
          [rejectionReason || 'Rejected by Administrator review.', reviewerId, reviewNotes || null, id]
        );
      } else {
        await run(
          `UPDATE account_requests 
           SET status = 'PENDING_SUPER_ADMIN_REVIEW',
               admin_reviewer_id = ?,
               admin_reviewed_at = datetime('now'),
               admin_review_notes = ?,
               updated_at = datetime('now')
           WHERE id = ?`,
          [reviewerId, reviewNotes || null, id]
        );
      }

      logAudit(reviewerId, `ADMIN_REVIEW_${action.toUpperCase()}`, 'account_requests', id, { action, reviewNotes }, req);

      const updated = await get('SELECT * FROM account_requests WHERE id = ?', [id]);
      return res.json({
        success: true,
        message: action === 'approve'
          ? 'Request approved by Administrator and forwarded to Super Admin for final activation.'
          : 'Request rejected.',
        data: updated
      });
    }

    if (reviewerRole === 'super_admin') {
      if (request.status !== 'PENDING_SUPER_ADMIN_REVIEW') {
        return res.status(400).json({
          success: false,
          error: 'Super Admin review requires request to be in PENDING_SUPER_ADMIN_REVIEW status.'
        });
      }

      if (action === 'reject') {
        await run(
          `UPDATE account_requests 
           SET status = 'REJECTED',
               rejection_reason = ?,
               super_admin_reviewer_id = ?,
               super_admin_reviewed_at = datetime('now'),
               super_admin_review_notes = ?,
               updated_at = datetime('now')
           WHERE id = ?`,
          [rejectionReason || 'Rejected by Super Admin.', reviewerId, reviewNotes || null, id]
        );

        logAudit(reviewerId, 'SUPER_ADMIN_REVIEW_REJECT', 'account_requests', id, { rejectionReason }, req);
        const updated = await get('SELECT * FROM account_requests WHERE id = ?', [id]);
        return res.json({ success: true, message: 'Request rejected.', data: updated });
      }

      // ATOMIC ACTIVATION BY SUPER ADMIN
      let createdUserId = null;
      let generatedStudentId = null;

      await transaction(async () => {
        const defaultPasswordHash = bcrypt.hashSync('BeastAcademy@2027', 10);

        if (request.requested_role === 'student') {
          generatedStudentId = await generateUniqueStudentId('2027');
          createdUserId = `user-stu-${Date.now()}`;

          // Create student user record
          await run(
            `INSERT INTO users (id, email, password_hash, role, name, phone, google_uid, status, is_active)
             VALUES (?, ?, ?, 'student', ?, ?, ?, 'active', 1)`,
            [
              createdUserId,
              request.email,
              defaultPasswordHash,
              request.name,
              request.phone,
              request.google_uid || null
            ]
          );

          // Create student profile
          await run(
            `INSERT INTO student_profiles (
              id, user_id, student_id_number, class_id, batch_id, academic_session_id,
              subscription_status, resource_permissions_json
            ) VALUES (?, ?, ?, ?, ?, ?, 'paid', '{"materials": true, "doubts": true, "exams": true}')`,
            [
              `stu-prof-${Date.now()}`,
              createdUserId,
              generatedStudentId,
              request.target_class_id,
              request.target_batch_id,
              request.target_session_id
            ]
          );

          // Create enrollment record
          if (request.target_batch_id && request.target_session_id) {
            await run(
              `INSERT INTO enrollments (id, student_id, batch_id, academic_session_id, status)
               VALUES (?, ?, ?, ?, 'active')`,
              [`enr-${Date.now()}`, createdUserId, request.target_batch_id, request.target_session_id]
            );
          }
        } else if (request.requested_role === 'teacher') {
          const employeeCode = await generateUniqueTeacherId('2027');
          createdUserId = `user-tch-${Date.now()}`;

          await run(
            `INSERT INTO users (id, email, password_hash, role, name, phone, google_uid, status, is_active)
             VALUES (?, ?, ?, 'teacher', ?, ?, ?, 'active', 1)`,
            [
              createdUserId,
              request.email,
              defaultPasswordHash,
              request.name,
              request.phone,
              request.google_uid || null
            ]
          );

          await run(
            `INSERT INTO teacher_profiles (id, user_id, employee_code, qualification, bio, contact_number)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [
              `tch-prof-${Date.now()}`,
              createdUserId,
              employeeCode,
              request.qualification || 'Faculty Member',
              request.notes || 'Institutional Faculty',
              request.phone || null
            ]
          );
        } else if (request.requested_role === 'admin') {
          const adminIdNumber = await generateUniqueAdminId('2027');
          createdUserId = `user-adm-${Date.now()}`;

          await run(
            `INSERT INTO users (id, email, password_hash, role, name, phone, google_uid, status, is_active)
             VALUES (?, ?, ?, 'admin', ?, ?, ?, 'active', 1)`,
            [
              createdUserId,
              request.email,
              defaultPasswordHash,
              request.name,
              request.phone,
              request.google_uid || null
            ]
          );

          await run(
            `INSERT INTO admin_profiles (id, user_id, admin_id_number, designation, created_by, permissions_json)
             VALUES (?, ?, ?, ?, ?, '{"students": true, "academics": true, "teachers": true}')`,
            [
              `adm-prof-${Date.now()}`,
              createdUserId,
              adminIdNumber,
              request.department || 'Administrator',
              reviewerId
            ]
          );
        }

        // Finalize account request record
        await run(
          `UPDATE account_requests 
           SET status = 'APPROVED',
               super_admin_reviewer_id = ?,
               super_admin_reviewed_at = datetime('now'),
               super_admin_review_notes = ?,
               generated_student_id = ?,
               created_user_id = ?,
               updated_at = datetime('now')
           WHERE id = ?`,
          [reviewerId, reviewNotes || null, generatedStudentId || null, createdUserId, id]
        );
      });

      logAudit(reviewerId, 'SUPER_ADMIN_ACTIVATION_COMPLETE', 'account_requests', id, {
        createdUserId,
        generatedStudentId,
        role: request.requested_role
      }, req);

      const updated = await get('SELECT * FROM account_requests WHERE id = ?', [id]);
      return res.json({
        success: true,
        message: `Account approved and activated successfully. Generated Student ID: ${generatedStudentId || 'N/A'}.`,
        data: updated
      });
    }

    res.status(403).json({ success: false, error: 'Unauthorized review role.' });
  } catch (err) {
    console.error('[REQUEST_REVIEW_ERROR]', err);
    res.status(500).json({ success: false, error: err.message || 'Internal server error during request review.' });
  }
});

module.exports = router;
