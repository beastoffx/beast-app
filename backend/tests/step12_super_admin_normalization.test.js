process.env.NODE_ENV = 'test';
const config = require('../src/config');
config.nodeEnv = 'test';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const { createApp } = require('../src/server');
const { initSchema, query, get, run, transaction } = require('../src/db');
const { seedDatabase } = require('../src/db/seed');
const { OtpService } = require('../src/services/otpService');

let server;
let baseUrl;

const CANONICAL_SUPER_ADMIN_EMAIL = 'beastiankankinara2026@gmail.com';
const ORDINARY_ADMIN_EMAIL = 'admin@beastacademy.edu';
const TEACHER_EMAIL = 'physics.teacher@beastacademy.edu';
const STUDENT_EMAIL = 'student1@beastacademy.edu';

let superAdminToken = '';
let adminToken = '';
let teacherToken = '';
let studentToken = '';

test.before(async () => {
  initSchema();
  seedDatabase();

  const app = createApp();
  server = http.createServer(app);

  await new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const addr = server.address();
      baseUrl = `http://127.0.0.1:${addr.port}`;
      resolve();
    });
  });

  // Login Super Admin
  const superRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: CANONICAL_SUPER_ADMIN_EMAIL, password: 'SuperAdmin@123' }
  });
  superAdminToken = superRes.data.token;

  // Login Normal Admin
  const adminRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: ORDINARY_ADMIN_EMAIL, password: 'Admin@123' }
  });
  adminToken = adminRes.data.token;

  // Login Teacher
  const teacherRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: TEACHER_EMAIL, password: 'Teacher@123' }
  });
  teacherToken = teacherRes.data.token;

  // Login Student
  const studentRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: STUDENT_EMAIL, password: 'Student@123' }
  });
  studentToken = studentRes.data.token;
});

test.after(async () => {
  if (server) {
    await new Promise((resolve) => server.close(resolve));
  }
});

async function api(path, options = {}) {
  const url = `${baseUrl}${path}`;
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  const res = await fetch(url, {
    ...options,
    headers,
    body: options.body ? (typeof options.body === 'string' ? options.body : JSON.stringify(options.body)) : undefined
  });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, data: json };
}

// ==================== SECTION 10: 19 MANDATORY TESTS ====================

test('BEAST Academy — Section 10: Super Admin Normalization & Security Suite', async (t) => {

  // 1. beastiankankinara2026@gmail.com database record has SUPER_ADMIN role
  await t.test('1. beastiankankinara2026@gmail.com database record has SUPER_ADMIN role', async () => {
    const user = get('SELECT id, email, role, status, is_active FROM users WHERE email = ?', [CANONICAL_SUPER_ADMIN_EMAIL]);
    assert.ok(user, 'Super Admin user record must exist in DB');
    assert.equal(user.email, CANONICAL_SUPER_ADMIN_EMAIL);
    assert.equal(user.role, 'super_admin');
    assert.equal(user.status, 'active');
    assert.equal(user.is_active, 1);

    const profile = get('SELECT permissions_json FROM admin_profiles WHERE user_id = ?', [user.id]);
    assert.ok(profile, 'Super Admin profile record must exist');
    const perms = JSON.parse(profile.permissions_json);
    assert.equal(perms.super_admin, true);
    assert.equal(perms.all, true);

    // Confirm ONLY ONE Super Admin exists in the database
    const allSuperUsers = query("SELECT id, email, role FROM users WHERE role = 'super_admin'");
    assert.equal(allSuperUsers.length, 1, 'There must be exactly ONE user with role=super_admin');
    assert.equal(allSuperUsers[0].email, CANONICAL_SUPER_ADMIN_EMAIL);
  });

  // 2. Existing old hardcoded Super Admin email does NOT receive Super Admin privileges
  await t.test('2. Existing old hardcoded Super Admin email does NOT receive Super Admin privileges', async () => {
    const oldAdmin = get('SELECT id, email, role FROM users WHERE email = ?', [ORDINARY_ADMIN_EMAIL]);
    assert.ok(oldAdmin, 'admin@beastacademy.edu should exist as an ordinary admin');
    assert.equal(oldAdmin.role, 'admin');

    const profile = get('SELECT permissions_json FROM admin_profiles WHERE user_id = ?', [oldAdmin.id]);
    const perms = JSON.parse(profile.permissions_json);
    assert.equal(Boolean(perms.super_admin), false, 'admin@beastacademy.edu must NOT have super_admin permission');

    // Attempting to access Super Admin endpoint using admin@beastacademy.edu token
    const res = await api('/api/admins', {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert.equal(res.status, 403, 'admin@beastacademy.edu must be forbidden from /api/admins');
  });

  // 3. A random Google account cannot become Super Admin
  await t.test('3. A random Google account cannot become Super Admin', async () => {
    const randomUid = `rand-google-uid-${Date.now()}`;
    const randomEmail = `hacker.${Date.now()}@gmail.com`;

    const res = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${randomUid}:${randomEmail}:Random Hacker`
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.status, 'UNLINKED');
    assert.equal(res.data.token, undefined);

    // Verify DB does not contain a super_admin user with this email or UID
    const dbCheck = get('SELECT * FROM users WHERE email = ? OR google_uid = ?', [randomEmail, randomUid]);
    assert.equal(dbCheck, undefined);
  });

  // 4. A normal Admin cannot access Super Admin endpoints
  await t.test('4. A normal Admin cannot access Super Admin endpoints', async () => {
    const listRes = await api('/api/admins', {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert.equal(listRes.status, 403);

    const postRes = await api('/api/admins', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { name: 'Attempt', email: 'attempt@beastacademy.edu', password: 'Password@123' }
    });
    assert.equal(postRes.status, 403);
  });

  // 5. A Teacher cannot access Super Admin endpoints
  await t.test('5. A Teacher cannot access Super Admin endpoints', async () => {
    const res = await api('/api/admins', {
      headers: { Authorization: `Bearer ${teacherToken}` }
    });
    assert.equal(res.status, 403);
  });

  // 6. A Student cannot access Super Admin endpoints
  await t.test('6. A Student cannot access Super Admin endpoints', async () => {
    const res = await api('/api/admins', {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(res.status, 403);
  });

  // 7. Super Admin can access /api/admins
  await t.test('7. Super Admin can access /api/admins', async () => {
    const res = await api('/api/admins', {
      headers: { Authorization: `Bearer ${superAdminToken}` }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.ok(Array.isArray(res.data.data));
    assert.ok(res.data.total >= 1);
  });

  // 8. Super Admin can create an Admin
  let newlyCreatedAdminId = '';
  const testNewAdminEmail = `test.subadmin.${Date.now()}@beastacademy.edu`;
  await t.test('8. Super Admin can create an Admin', async () => {
    const res = await api('/api/admins', {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: {
        name: 'New Sub Admin',
        email: testNewAdminEmail,
        password: 'SubAdminPassword@123',
        designation: 'Course Coordinator'
      }
    });

    assert.equal(res.status, 201);
    assert.equal(res.data.success, true);
    assert.ok(res.data.id);
    assert.ok(res.data.adminIdNumber.startsWith('ADM-2027-'));
    newlyCreatedAdminId = res.data.id;

    // Verify in database
    const createdUser = get('SELECT id, role, status FROM users WHERE id = ?', [newlyCreatedAdminId]);
    assert.equal(createdUser.role, 'admin');
    assert.equal(createdUser.status, 'active');
  });

  // 9. Admin cannot create another Admin
  await t.test('9. Admin cannot create another Admin', async () => {
    const res = await api('/api/admins', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        name: 'Unauthorized Admin',
        email: `unauth.${Date.now()}@beastacademy.edu`,
        password: 'Password@123'
      }
    });
    assert.equal(res.status, 403);
    assert.match(res.data.error, /Super Admin/i);
  });

  // 10. Admin cannot promote itself or another user to Super Admin
  await t.test('10. Admin cannot promote itself or another user to Super Admin', async () => {
    const res = await api(`/api/admins/${newlyCreatedAdminId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        is_super_admin: true,
        permissions: { super_admin: true, all: true }
      }
    });
    assert.equal(res.status, 403);

    // Verify in database that target account was not elevated
    const target = get('SELECT role FROM users WHERE id = ?', [newlyCreatedAdminId]);
    assert.equal(target.role, 'admin');
  });

  // 11. Role is loaded from DB, not client JSON
  await t.test('11. Role is loaded from DB, not client JSON', async () => {
    // A forged JWT token with role="super_admin" but corresponding to a normal admin in DB
    const forgedToken = jwt.sign(
      { id: get("SELECT id FROM users WHERE email = ?", [ORDINARY_ADMIN_EMAIL]).id, role: 'super_admin' },
      config.jwtSecret,
      { expiresIn: '1h' }
    );

    const res = await api('/api/admins', {
      headers: { Authorization: `Bearer ${forgedToken}` }
    });
    // authenticateToken reads the actual user from DB, setting role='admin', so authorizeSuperAdmin blocks it with 403
    assert.equal(res.status, 403);
  });

  // 12. Changing a user's DB role changes authorization behavior
  await t.test('12. Changing a user\'s DB role changes authorization behavior', async () => {
    // Generate token for newlyCreatedAdminId
    const testLogin = await api('/api/auth/login', {
      method: 'POST',
      body: { email: testNewAdminEmail, password: 'SubAdminPassword@123' }
    });
    assert.equal(testLogin.status, 200);
    const dynamicToken = testLogin.data.token;

    // As ordinary admin, access is forbidden
    const beforeRes = await api('/api/admins', {
      headers: { Authorization: `Bearer ${dynamicToken}` }
    });
    assert.equal(beforeRes.status, 403);

    // Promote in DB directly
    run("UPDATE users SET role = 'super_admin' WHERE id = ?", [newlyCreatedAdminId]);
    run("UPDATE admin_profiles SET permissions_json = '{\"super_admin\": true, \"all\": true}' WHERE user_id = ?", [newlyCreatedAdminId]);

    // Access is now granted because authenticateToken evaluates the live DB role
    const afterRes = await api('/api/admins', {
      headers: { Authorization: `Bearer ${dynamicToken}` }
    });
    assert.equal(afterRes.status, 200);
    assert.equal(afterRes.data.success, true);

    // Revert DB role back to admin
    run("UPDATE users SET role = 'admin' WHERE id = ?", [newlyCreatedAdminId]);
    run("UPDATE admin_profiles SET permissions_json = '{\"students\": true}' WHERE user_id = ?", [newlyCreatedAdminId]);

    // Access is again forbidden
    const revertRes = await api('/api/admins', {
      headers: { Authorization: `Bearer ${dynamicToken}` }
    });
    assert.equal(revertRes.status, 403);
  });

  // 13. Suspended Super Admin cannot authenticate/access protected resources
  await t.test('13. Suspended Super Admin cannot authenticate/access protected resources', async () => {
    const superAdmin = get('SELECT id FROM users WHERE email = ?', [CANONICAL_SUPER_ADMIN_EMAIL]);

    // Temporarily suspend Super Admin
    run("UPDATE users SET status = 'suspended', is_active = 0 WHERE id = ?", [superAdmin.id]);

    // New login attempt is rejected
    const loginRes = await api('/api/auth/login', {
      method: 'POST',
      body: { email: CANONICAL_SUPER_ADMIN_EMAIL, password: 'SuperAdmin@123' }
    });
    assert.equal(loginRes.status, 403);

    // Existing active JWT token is rejected on protected endpoints
    const meRes = await api('/api/auth/me', {
      headers: { Authorization: `Bearer ${superAdminToken}` }
    });
    assert.equal(meRes.status, 403);

    // Restore Super Admin
    run("UPDATE users SET status = 'active', is_active = 1 WHERE id = ?", [superAdmin.id]);

    // Now accesses successfully again
    const restoredMeRes = await api('/api/auth/me', {
      headers: { Authorization: `Bearer ${superAdminToken}` }
    });
    assert.equal(restoredMeRes.status, 200);
  });

  // 14. Last active Super Admin cannot be removed
  await t.test('14. Last active Super Admin cannot be removed', async () => {
    const superAdmin = get('SELECT id FROM users WHERE email = ?', [CANONICAL_SUPER_ADMIN_EMAIL]);

    // Attempt self-suspension via API
    const suspRes = await api(`/api/admins/${superAdmin.id}/suspend`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { reason: 'Self suspend test' }
    });
    assert.equal(suspRes.status, 400);
    assert.match(suspRes.data.error, /cannot suspend their own account/i);

    // Attempt self-archive via API
    const archRes = await api(`/api/admins/${superAdmin.id}/archive`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { reason: 'Self archive test' }
    });
    assert.equal(archRes.status, 400);
    assert.match(archRes.data.error, /cannot archive their own account/i);

    // Attempt self-demotion via API
    const demoteRes = await api(`/api/admins/${superAdmin.id}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { is_super_admin: false }
    });
    assert.equal(demoteRes.status, 400);
    assert.match(demoteRes.data.error, /only remaining active Super Administrator/i);
  });

  // 15. Student activation still works
  const TEST15_STUDENT_ID = 'BST-2027-00015';
  const TEST15_STUDENT_USER_ID = 'user-stu-test15';
  const TEST15_STUDENT_EMAIL = 'riya.test15@beastacademy.edu';
  const TEST15_STUDENT_PHONE = '+91 98765 77777';
  const TEST15_GOOGLE_UID = 'google-uid-test15';

  await t.test('15. Student activation still works', async () => {
    // Clean up any previous test runs
    run('DELETE FROM phone_verifications WHERE student_id_number = ?', [TEST15_STUDENT_ID]);
    run('DELETE FROM enrollments WHERE student_id = ?', [TEST15_STUDENT_USER_ID]);
    run('DELETE FROM student_profiles WHERE student_id_number = ?', [TEST15_STUDENT_ID]);
    run('DELETE FROM users WHERE id = ?', [TEST15_STUDENT_USER_ID]);

    // Pre-provision student
    run(
      `INSERT INTO users (id, email, password_hash, role, name, phone, phone_verified, status, is_active)
       VALUES (?, ?, 'HASH', 'student', 'Riya Sen', ?, 0, 'pending_activation', 1)`,
      [TEST15_STUDENT_USER_ID, TEST15_STUDENT_EMAIL, TEST15_STUDENT_PHONE]
    );
    run(
      `INSERT INTO student_profiles (id, user_id, student_id_number, class_id, batch_id, academic_session_id, subscription_status)
       VALUES ('stu-prof-test15', ?, ?, 'class-12-sci', 'batch-pcm-2027-a', 'session-2026-2027', 'paid')`,
      [TEST15_STUDENT_USER_ID, TEST15_STUDENT_ID]
    );

    // 1. Verify Student ID
    const verifyIdRes = await api('/api/auth/activate/student', {
      method: 'POST',
      body: { studentIdNumber: TEST15_STUDENT_ID }
    });
    assert.equal(verifyIdRes.status, 200);
    assert.equal(verifyIdRes.data.eligible, true);
    assert.equal(verifyIdRes.data.name, 'Riya Sen');

    // 2. Request OTP
    const otpRes = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: TEST15_GOOGLE_UID,
        studentIdNumber: TEST15_STUDENT_ID,
        phone: TEST15_STUDENT_PHONE
      }
    });
    assert.equal(otpRes.status, 200);
    assert.equal(otpRes.data.success, true);
    assert.ok(otpRes.data.sessionId);

    // Retrieve active OTP code from dev console provider
    const correctOtp = OtpService.getActiveProvider().getTestOtp(TEST15_STUDENT_PHONE);
    assert.ok(correctOtp, 'Active OTP must exist in test mode');

    // 3. Verify OTP and complete activation
    const linkRes = await api('/api/auth/activate/verify', {
      method: 'POST',
      body: {
        sessionId: otpRes.data.sessionId,
        otp: correctOtp,
        googleUid: TEST15_GOOGLE_UID,
        studentIdNumber: TEST15_STUDENT_ID
      }
    });

    assert.equal(linkRes.status, 200);
    assert.equal(linkRes.data.success, true);
    assert.equal(linkRes.data.status, 'ACTIVATED');
    assert.ok(linkRes.data.token);

    // Verify DB user is active and linked
    const user = get('SELECT status, phone_verified, google_uid FROM users WHERE id = ?', [TEST15_STUDENT_USER_ID]);
    assert.equal(user.status, 'active');
    assert.equal(user.phone_verified, 1);
    assert.equal(user.google_uid, TEST15_GOOGLE_UID);
  });

  // 16. New-device Google login still restores the same account
  await t.test('16. New-device Google login still restores the same account', async () => {
    const res = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${TEST15_GOOGLE_UID}:${TEST15_STUDENT_EMAIL}:Riya Sen`
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.status, 'LINKED');
    assert.equal(res.data.user.id, TEST15_STUDENT_USER_ID);
    assert.equal(res.data.profile.student_id_number, TEST15_STUDENT_ID);
    assert.ok(res.data.token);
  });

  // 17. Duplicate Google UID remains blocked
  await t.test('17. Duplicate Google UID remains blocked', async () => {
    // Attempt to send OTP for another student using already linked TEST15_GOOGLE_UID
    const DUP_ID = 'BST-2027-00017';
    const DUP_UID = 'user-stu-test17';
    run('DELETE FROM phone_verifications WHERE student_id_number = ?', [DUP_ID]);
    run('DELETE FROM student_profiles WHERE student_id_number = ?', [DUP_ID]);
    run('DELETE FROM users WHERE id = ?', [DUP_UID]);

    run(
      `INSERT INTO users (id, email, password_hash, role, name, phone, phone_verified, status, is_active)
       VALUES (?, 'dup@beastacademy.edu', 'HASH', 'student', 'Dup Student', '+91 98765 88888', 0, 'pending_activation', 1)`,
      [DUP_UID]
    );
    run(
      `INSERT INTO student_profiles (id, user_id, student_id_number, class_id, batch_id, academic_session_id)
       VALUES ('stu-prof-test17', ?, ?, 'class-12-sci', 'batch-pcm-2027-a', 'session-2026-2027')`,
      [DUP_UID, DUP_ID]
    );

    // Attempt to send OTP with already-linked Google UID
    const res = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: TEST15_GOOGLE_UID,
        studentIdNumber: DUP_ID,
        phone: '+91 98765 88888'
      }
    });

    assert.equal(res.status, 409);
    assert.match(res.data.error, /already linked to another institutional identity/i);
  });

  // 18. Duplicate Student ID remains blocked
  await t.test('18. Duplicate Student ID remains blocked', async () => {
    // Attempt to send OTP for TEST15_STUDENT_ID with a different Google account
    const res = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: 'google-uid-new-different-999',
        studentIdNumber: TEST15_STUDENT_ID,
        phone: '+91 98765 77777'
      }
    });
    assert.equal(res.status, 409);
    assert.match(res.data.error, /already linked to another Google account/i);
  });

  // 19. Old hardcoded email strings are absent from authorization source code
  await t.test('19. Old hardcoded email strings are absent from authorization source code', async () => {
    const authDirPaths = [
      path.join(__dirname, '../src/middleware'),
      path.join(__dirname, '../src/routes'),
      path.join(__dirname, '../src/services')
    ];

    const violations = [];

    for (const dirPath of authDirPaths) {
      if (!fs.existsSync(dirPath)) continue;
      const files = fs.readdirSync(dirPath);

      for (const file of files) {
        if (!file.endsWith('.js')) continue;
        const filePath = path.join(dirPath, file);
        const content = fs.readFileSync(filePath, 'utf8');

        // Check for old hardcoded email string
        if (content.includes('admin@beastacademy.edu')) {
          violations.push({
            file: path.relative(path.join(__dirname, '..'), filePath),
            reason: 'Found forbidden old admin email in authorization source code: admin@beastacademy.edu'
          });
        }

        // Check for any hardcoded Super Admin email authorization
        if (content.includes('beastiankankinara2026@gmail.com')) {
          violations.push({
            file: path.relative(path.join(__dirname, '..'), filePath),
            reason: 'Found hardcoded Super Admin email in authorization code (provisioning belongs only in seed): beastiankankinara2026@gmail.com'
          });
        }

        // Check for regex or string matching on email to assign super_admin
        if (/role\s*=\s*['"]super_admin['"]\s*;/i.test(content) && content.includes('email')) {
          // Verify it's not a dynamic assignment from DB
          const lines = content.split('\n');
          for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.includes('email') && line.includes('super_admin') && (line.includes('===') || line.includes('=='))) {
              violations.push({
                file: `${path.relative(path.join(__dirname, '..'), filePath)}:${i + 1}`,
                reason: `Found conditional email check assigning or checking super_admin: "${line.trim()}"`
              });
            }
          }
        }
      }
    }

    assert.equal(
      violations.length,
      0,
      `Found ${violations.length} authorization source code violations:\n` +
      violations.map(v => ` - [${v.file}] ${v.reason}`).join('\n')
    );
  });

  // Clean up test subadmin
  if (newlyCreatedAdminId) {
    run('DELETE FROM admin_profiles WHERE user_id = ?', [newlyCreatedAdminId]);
    run('DELETE FROM users WHERE id = ?', [newlyCreatedAdminId]);
  }
});
