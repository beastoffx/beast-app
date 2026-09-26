process.env.NODE_ENV = 'test';
const config = require('../src/config');
config.nodeEnv = 'test';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createApp } = require('../src/server');
const { initSchema, query, get, run, transaction } = require('../src/db');
const { seedDatabase } = require('../src/db/seed');
const { OtpService } = require('../src/services/otpService');

let server;
let baseUrl;

// Test accounts identifiers
const TEST_STUDENT_USER_ID = 'user-stu-step12';
const TEST_STUDENT_ID = 'BST-2027-00012';
const TEST_STUDENT_EMAIL = 'kabir.step12@beastacademy.edu';
const TEST_STUDENT_PHONE = '+91 98765 44444';
const TEST_STUDENT_NAME = 'Kabir Singhania';
const TEST_STUDENT_GOOGLE_UID = 'google-uid-kabir-step12';

const DUP_STUDENT_USER_ID = 'user-stu-dup-step12';
const DUP_STUDENT_ID = 'BST-2027-00013';
const DUP_STUDENT_EMAIL = 'aditi.dup@beastacademy.edu';
const DUP_STUDENT_PHONE = '+91 98765 55555';
const DUP_STUDENT_NAME = 'Aditi Rao';

const TEST_ADMIN_USER_ID = 'user-adm-step12';
const TEST_ADMIN_EMAIL = 'neha.admin@beastacademy.edu';
const TEST_ADMIN_GOOGLE_UID = 'google-uid-neha-step12';

const SUPER_ADMIN_EMAIL = 'beastiankankinara2026@gmail.com';
const SUPER_ADMIN_GOOGLE_UID = 'google-uid-super-step12';

let activatedStudentToken = '';
let activationSessionId = '';

test.before(async () => {
  initSchema();
  seedDatabase();

  // Reset test artifacts unconditionally for idempotency across repeated test runs
  run('DELETE FROM phone_verifications WHERE student_id_number IN (?, ?)', [TEST_STUDENT_ID, DUP_STUDENT_ID]);
  run('DELETE FROM phone_verifications WHERE phone IN (?, ?)', [TEST_STUDENT_PHONE, DUP_STUDENT_PHONE]);
  run('DELETE FROM enrollments WHERE student_id IN (?, ?)', [TEST_STUDENT_USER_ID, DUP_STUDENT_USER_ID]);
  run('DELETE FROM student_profiles WHERE student_id_number IN (?, ?)', [TEST_STUDENT_ID, DUP_STUDENT_ID]);
  run('DELETE FROM student_profiles WHERE user_id IN (?, ?)', [TEST_STUDENT_USER_ID, DUP_STUDENT_USER_ID]);
  run('DELETE FROM admin_profiles WHERE user_id = ?', [TEST_ADMIN_USER_ID]);
  run('DELETE FROM audit_logs WHERE user_id IN (?, ?, ?)', [TEST_STUDENT_USER_ID, DUP_STUDENT_USER_ID, TEST_ADMIN_USER_ID]);
  run('DELETE FROM users WHERE id IN (?, ?, ?)', [TEST_STUDENT_USER_ID, DUP_STUDENT_USER_ID, TEST_ADMIN_USER_ID]);
  run('DELETE FROM users WHERE email IN (?, ?, ?)', [TEST_STUDENT_EMAIL, DUP_STUDENT_EMAIL, TEST_ADMIN_EMAIL]);

  // Reset Super Admin Google UID for Google account resolution test
  run("UPDATE users SET google_uid = NULL WHERE email IN (?, 'admin@beastacademy.edu')", [SUPER_ADMIN_EMAIL]);

  // Insert pre-provisioned unactivated test student 1 (Kabir Singhania)
  run(
    `INSERT INTO users (id, email, password_hash, role, name, phone, phone_verified, status, is_active)
     VALUES (?, ?, 'HASH_STU', 'student', ?, ?, 0, 'pending_activation', 1)`,
    [TEST_STUDENT_USER_ID, TEST_STUDENT_EMAIL, TEST_STUDENT_NAME, TEST_STUDENT_PHONE]
  );
  run(
    `INSERT INTO student_profiles 
     (id, user_id, student_id_number, class_id, batch_id, academic_session_id, subscription_status, access_start_date, access_end_date, resource_permissions_json)
     VALUES (?, ?, ?, 'class-12-sci', 'batch-pcm-2027-a', 'session-2026-2027', 'paid', '2026-01-01', '2027-12-31', '{"materials": true, "doubts": true, "exams": true}')`,
    ['stu-prof-step12', TEST_STUDENT_USER_ID, TEST_STUDENT_ID]
  );
  run(
    `INSERT INTO enrollments (id, student_id, batch_id, academic_session_id, status)
     VALUES ('enr-step12', ?, 'batch-pcm-2027-a', 'session-2026-2027', 'active')`,
    [TEST_STUDENT_USER_ID]
  );

  // Insert pre-provisioned unactivated test student 2 (Aditi Rao) for duplicate checks
  run(
    `INSERT INTO users (id, email, password_hash, role, name, phone, phone_verified, status, is_active)
     VALUES (?, ?, 'HASH_DUP', 'student', ?, ?, 0, 'pending_activation', 1)`,
    [DUP_STUDENT_USER_ID, DUP_STUDENT_EMAIL, DUP_STUDENT_NAME, DUP_STUDENT_PHONE]
  );
  run(
    `INSERT INTO student_profiles 
     (id, user_id, student_id_number, class_id, batch_id, academic_session_id, subscription_status)
     VALUES (?, ?, ?, 'class-12-sci', 'batch-pcm-2027-a', 'session-2026-2027', 'paid')`,
    ['stu-prof-dup-step12', DUP_STUDENT_USER_ID, DUP_STUDENT_ID]
  );
  run(
    `INSERT INTO enrollments (id, student_id, batch_id, academic_session_id, status)
     VALUES ('enr-dup-step12', ?, 'batch-pcm-2027-a', 'session-2026-2027', 'active')`,
    [DUP_STUDENT_USER_ID]
  );

  // Insert pre-provisioned admin (Neha Admin)
  run(
    `INSERT INTO users (id, email, password_hash, role, name, phone, phone_verified, status, is_active)
     VALUES (?, ?, 'HASH_ADM', 'admin', 'Neha Admin', '+91 98765 66666', 1, 'active', 1)`,
    [TEST_ADMIN_USER_ID, TEST_ADMIN_EMAIL]
  );
  run(
    `INSERT INTO admin_profiles (id, user_id, designation, permissions_json, admin_id_number)
     VALUES ('adm-prof-step12', ?, 'Senior Academic Coordinator', '{"students": true, "academics": true}', 'ADM-2027-00099')`,
    [TEST_ADMIN_USER_ID]
  );

  const app = createApp();
  server = http.createServer(app);

  await new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const addr = server.address();
      baseUrl = `http://127.0.0.1:${addr.port}`;
      resolve();
    });
  });
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

// ==================== 25-POINT AUTHENTICATION TEST MATRIX ====================

test('BEAST Academy — Step 12: Real Google Sign-In & Student Activation Matrix', async (t) => {

  // 1. Google identity validation (valid and invalid tokens)
  await t.test('1. Google identity validation (valid and invalid tokens)', async () => {
    // Missing token
    const resEmpty = await api('/api/auth/google', { method: 'POST', body: {} });
    assert.equal(resEmpty.status, 400);
    assert.equal(resEmpty.data.success, false);
    assert.match(resEmpty.data.error, /required/i);

    // Invalid token signature
    const resInvalid = await api('/api/auth/google', {
      method: 'POST',
      body: { idToken: 'mock-google-token-invalid' }
    });
    assert.equal(resInvalid.status, 401);
    assert.equal(resInvalid.data.success, false);
    assert.match(resInvalid.data.error, /invalid/i);

    // Valid token for unlinked user returns 200 with UNLINKED status
    const resValid = await api('/api/auth/google', {
      method: 'POST',
      body: { idToken: `mock-google-token:uid-valid-1:someone@gmail.com:Someone Special` }
    });
    assert.equal(resValid.status, 200);
    assert.equal(resValid.data.success, true);
    assert.equal(resValid.data.status, 'UNLINKED');
  });

  // 2. Unknown Google account returns UNLINKED status
  await t.test('2. Unknown Google account returns UNLINKED status', async () => {
    const unlinkedUid = `google-uid-unlinked-${Date.now()}`;
    const res = await api('/api/auth/google', {
      method: 'POST',
      body: { idToken: `mock-google-token:${unlinkedUid}:unlinked.fresh@gmail.com:Unlinked Student` }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.status, 'UNLINKED');
    assert.equal(res.data.googleUid, unlinkedUid);
    assert.equal(res.data.email, 'unlinked.fresh@gmail.com');
    assert.ok(res.data.message.includes('not yet linked'));
  });

  // 3. Student ID validation returns safe identity info
  await t.test('3. Student ID validation returns safe identity info', async () => {
    const res = await api('/api/auth/activate/student', {
      method: 'POST',
      body: { studentIdNumber: TEST_STUDENT_ID }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.eligible, true);
    assert.equal(res.data.studentIdNumber, TEST_STUDENT_ID);
    assert.equal(res.data.name, TEST_STUDENT_NAME);
    assert.equal(res.data.className, 'Class 12');
    assert.equal(res.data.batchName, 'PCM-2027-A');
    assert.equal(res.data.phoneMasked, '+91 ****** 4444');

    // Crucial security check: sensitive secrets, password hash, internal tokens must NEVER leak
    assert.equal(res.data.password_hash, undefined);
    assert.equal(res.data.emergency_contact, undefined);
    assert.equal(res.data.token, undefined);
  });

  // 4. Invalid Student ID returns 404
  await t.test('4. Invalid Student ID returns 404', async () => {
    const res = await api('/api/auth/activate/student', {
      method: 'POST',
      body: { studentIdNumber: 'BST-INVALID-99999' }
    });
    assert.equal(res.status, 404);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /Invalid Student ID/i);
  });

  // 5. Already-linked Student ID returns 409
  await t.test('5. Already-linked Student ID returns 409', async () => {
    // Student 1 (Aarav Mehta, STU-2026-001) has existing link or link student 1 temporarily
    run("UPDATE users SET google_uid = 'existing-google-uid-01' WHERE id = 'user-student-01'");

    const res = await api('/api/auth/activate/student', {
      method: 'POST',
      body: {
        studentIdNumber: 'STU-2026-001',
        googleUid: 'different-google-uid-999'
      }
    });
    assert.equal(res.status, 409);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /already linked/i);

    // Revert user-student-01 google_uid
    run("UPDATE users SET google_uid = NULL WHERE id = 'user-student-01'");
  });

  // 6. Phone OTP generation with SHA-256 hash in database
  await t.test('6. Phone OTP generation with SHA-256 hash in database', async () => {
    const res = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: TEST_STUDENT_GOOGLE_UID,
        studentIdNumber: TEST_STUDENT_ID,
        phone: TEST_STUDENT_PHONE
      }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.ok(res.data.sessionId);
    assert.ok(res.data.expiresAt);
    activationSessionId = res.data.sessionId;

    // Verify database record
    const record = get('SELECT * FROM phone_verifications WHERE session_id = ?', [activationSessionId]);
    assert.ok(record, 'Verification record must exist in phone_verifications');
    assert.equal(record.phone, TEST_STUDENT_PHONE);
    assert.equal(record.student_id_number, TEST_STUDENT_ID);
    assert.equal(record.google_uid, TEST_STUDENT_GOOGLE_UID);
    assert.equal(record.is_verified, 0);
    assert.equal(record.attempts, 0);

    // Cryptographic verification: otp_hash must be a 64-char SHA-256 hex string
    assert.equal(record.otp_hash.length, 64);
    assert.match(record.otp_hash, /^[a-f0-9]{64}$/i);

    // Raw 6-digit OTP code must NOT be stored in database
    assert.equal(record.otp_code, undefined);
  });

  // 7. Incorrect OTP rejected with 400
  await t.test('7. Incorrect OTP rejected with 400', async () => {
    const res = await api('/api/auth/activate/verify', {
      method: 'POST',
      body: {
        sessionId: activationSessionId,
        otp: '000000', // incorrect code
        googleUid: TEST_STUDENT_GOOGLE_UID,
        studentIdNumber: TEST_STUDENT_ID
      }
    });
    assert.equal(res.status, 400);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /Incorrect verification code/i);

    // Verify attempts incremented in database
    const record = get('SELECT attempts FROM phone_verifications WHERE session_id = ?', [activationSessionId]);
    assert.equal(record.attempts, 1);
  });

  // 8. Expired OTP rejected with 400
  await t.test('8. Expired OTP rejected with 400', async () => {
    // Manually expire the session in the database
    run("UPDATE phone_verifications SET expires_at = datetime('now', '-5 minutes') WHERE session_id = ?", [activationSessionId]);

    const res = await api('/api/auth/activate/verify', {
      method: 'POST',
      body: {
        sessionId: activationSessionId,
        otp: '123456',
        googleUid: TEST_STUDENT_GOOGLE_UID,
        studentIdNumber: TEST_STUDENT_ID
      }
    });
    assert.equal(res.status, 400);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /expired/i);
  });

  // 9. Successful activation links Google UID + Student ID + Phone
  await t.test('9. Successful activation links Google UID + Student ID + Phone', async () => {
    // Clear previous phone verifications for clean test isolation
    run('DELETE FROM phone_verifications WHERE student_id_number = ?', [TEST_STUDENT_ID]);

    // Request fresh valid OTP
    const otpRes = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: TEST_STUDENT_GOOGLE_UID,
        studentIdNumber: TEST_STUDENT_ID,
        phone: TEST_STUDENT_PHONE
      }
    });
    assert.equal(otpRes.status, 200);
    const validSessionId = otpRes.data.sessionId;

    // Retrieve generated OTP from test provider
    const correctOtp = OtpService.getActiveProvider().getTestOtp(TEST_STUDENT_PHONE);
    assert.ok(correctOtp, 'Test OTP must be retrievable from dev console provider');

    const res = await api('/api/auth/activate/verify', {
      method: 'POST',
      body: {
        sessionId: validSessionId,
        otp: correctOtp,
        googleUid: TEST_STUDENT_GOOGLE_UID,
        studentIdNumber: TEST_STUDENT_ID
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.status, 'ACTIVATED');
    assert.ok(res.data.token, 'Must return signed JWT session token');
    activatedStudentToken = res.data.token;

    assert.equal(res.data.user.google_uid, TEST_STUDENT_GOOGLE_UID);
    assert.equal(res.data.user.phone, TEST_STUDENT_PHONE);
    assert.equal(res.data.user.phone_verified, true);
    assert.equal(res.data.user.status, 'active');
  });

  // 10. Atomically links Google UID and activates student
  await t.test('10. Atomically links Google UID and activates student', async () => {
    const updatedUser = get('SELECT id, google_uid, phone, phone_verified, status, is_active FROM users WHERE id = ?', [TEST_STUDENT_USER_ID]);
    assert.ok(updatedUser);
    assert.equal(updatedUser.google_uid, TEST_STUDENT_GOOGLE_UID);
    assert.equal(updatedUser.phone, TEST_STUDENT_PHONE);
    assert.equal(updatedUser.phone_verified, 1);
    assert.equal(updatedUser.status, 'active');
    assert.equal(updatedUser.is_active, 1);

    // Verify audit log has record of student activation
    const auditRecord = get("SELECT * FROM audit_logs WHERE user_id = ? AND action = 'STUDENT_ACTIVATED'", [TEST_STUDENT_USER_ID]);
    assert.ok(auditRecord, 'Audit log entry must be created on activation');
  });

  // 11. Duplicate Google UID prevention on activation
  await t.test('11. Duplicate Google UID prevention on activation', async () => {
    // Attempt to send OTP for Aditi Rao using Kabir's already-linked Google UID
    const res = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: TEST_STUDENT_GOOGLE_UID, // already linked to Kabir Singhania
        studentIdNumber: DUP_STUDENT_ID,
        phone: DUP_STUDENT_PHONE
      }
    });
    assert.equal(res.status, 409);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /already linked to another institutional identity/i);
  });

  // 12. Duplicate Student ID activation prevention
  await t.test('12. Duplicate Student ID activation prevention', async () => {
    // Clear previous phone verifications for clean test isolation
    run('DELETE FROM phone_verifications WHERE student_id_number = ?', [TEST_STUDENT_ID]);

    // Attempt to activate Kabir's Student ID with a different Google account
    const res = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: 'google-uid-brand-new-999',
        studentIdNumber: TEST_STUDENT_ID, // already activated and linked
        phone: TEST_STUDENT_PHONE
      }
    });
    assert.equal(res.status, 409);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /already linked to another Google account/i);
  });

  // 13. New-device login: returning Google user gets instant session without Student ID prompt
  let returningSessionToken = '';
  await t.test('13. New-device login: returning Google user gets instant session without Student ID prompt', async () => {
    // Simulate login from a new device/browser with the linked Google token
    const res = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${TEST_STUDENT_GOOGLE_UID}:${TEST_STUDENT_EMAIL}:Kabir Singhania`
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.status, 'LINKED');
    assert.ok(res.data.token, 'Must return valid JWT token immediately');
    returningSessionToken = res.data.token;
    assert.equal(res.data.user.id, TEST_STUDENT_USER_ID);
    assert.equal(res.data.user.google_uid, TEST_STUDENT_GOOGLE_UID);
    assert.equal(res.data.user.phone_verified, true);
  });

  // 14. Student profile restoration (class, batch, session)
  await t.test('14. Student profile restoration (class, batch, session)', async () => {
    const res = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${TEST_STUDENT_GOOGLE_UID}:${TEST_STUDENT_EMAIL}:Kabir Singhania`
      }
    });

    assert.ok(res.data.profile, 'Profile object must be present in response');
    assert.equal(res.data.profile.student_id_number, TEST_STUDENT_ID);
    assert.equal(res.data.profile.class_name, 'Class 12');
    assert.equal(res.data.profile.batch_name, 'PCM-2027-A');
    assert.equal(res.data.profile.session_name, '2026-2027');
  });

  // 15. Paid subscription restoration upon new-device login
  await t.test('15. Paid subscription restoration upon new-device login', async () => {
    // 1. Verify subscription in profile
    const authRes = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${TEST_STUDENT_GOOGLE_UID}:${TEST_STUDENT_EMAIL}:Kabir Singhania`
      }
    });
    assert.equal(authRes.data.profile.subscription_status, 'paid');

    // 2. Verify student can access paid educational resources using returning session token
    const matRes = await api('/api/materials/mat-chm-01/download-url', {
      headers: { Authorization: `Bearer ${returningSessionToken}` }
    });
    assert.equal(matRes.status, 200);
    assert.equal(matRes.data.success, true);
    assert.ok(matRes.data.downloadUrl);
  });

  // 16. Suspended account rejection (403) on Google login
  await t.test('16. Suspended account rejection (403) on Google login', async () => {
    // Suspend test student
    run("UPDATE users SET status = 'suspended', is_active = 0 WHERE id = ?", [TEST_STUDENT_USER_ID]);

    const res = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${TEST_STUDENT_GOOGLE_UID}:${TEST_STUDENT_EMAIL}:Kabir Singhania`
      }
    });

    assert.equal(res.status, 403);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /suspended/i);
  });

  // 17. Archived account rejection (403) on Google login
  await t.test('17. Archived account rejection (403) on Google login', async () => {
    // Archive test student
    run("UPDATE users SET status = 'archived', is_active = 0 WHERE id = ?", [TEST_STUDENT_USER_ID]);

    const res = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${TEST_STUDENT_GOOGLE_UID}:${TEST_STUDENT_EMAIL}:Kabir Singhania`
      }
    });

    assert.equal(res.status, 403);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /archived/i);
  });

  // 18. Restored account regains Google login access
  await t.test('18. Restored account regains Google login access', async () => {
    // Restore test student to active
    run("UPDATE users SET status = 'active', is_active = 1 WHERE id = ?", [TEST_STUDENT_USER_ID]);

    const res = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${TEST_STUDENT_GOOGLE_UID}:${TEST_STUDENT_EMAIL}:Kabir Singhania`
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.status, 'LINKED');
    assert.ok(res.data.token);
  });

  // 19. Student cannot self-register without institute ID
  await t.test('19. Student cannot self-register without institute ID', async () => {
    // Attempting direct self-registration route (must not exist or fail)
    const res = await api('/api/auth/register', {
      method: 'POST',
      body: {
        email: 'attacker@gmail.com',
        name: 'Attacker Student',
        role: 'student'
      }
    });
    // System enforces no public unverified registration
    assert.equal(res.status, 404);
  });

  // 20. Student cannot change their own Student ID
  await t.test('20. Student cannot change their own Student ID', async () => {
    const res = await api(`/api/academics/students/${TEST_STUDENT_USER_ID}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${activatedStudentToken}` },
      body: { student_id_number: 'BST-HACKED-99999' }
    });

    // Student role lacks permission to update student profiles
    assert.equal(res.status, 403);
    assert.equal(res.data.success, false);

    // Verify database record remains unchanged
    const profile = get('SELECT student_id_number FROM student_profiles WHERE user_id = ?', [TEST_STUDENT_USER_ID]);
    assert.equal(profile.student_id_number, TEST_STUDENT_ID);
  });

  // 21. Student cannot change paid status
  await t.test('21. Student cannot change paid status', async () => {
    const res = await api(`/api/academics/students/${TEST_STUDENT_USER_ID}/subscription`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${activatedStudentToken}` },
      body: { subscription_status: 'paid' }
    });

    // Student role lacks permission
    assert.equal(res.status, 403);
    assert.equal(res.data.success, false);
  });

  // 22. Student cannot change role
  await t.test('22. Student cannot change role', async () => {
    const res = await api(`/api/admins`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${activatedStudentToken}` },
      body: { name: 'Escalated Admin', email: 'escalated@beastacademy.edu' }
    });

    assert.equal(res.status, 403);
    assert.equal(res.data.success, false);
  });

  // 23. Admin Google account resolution
  await t.test('23. Admin Google account resolution', async () => {
    const res = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${TEST_ADMIN_GOOGLE_UID}:${TEST_ADMIN_EMAIL}:Neha Admin`
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.status, 'LINKED');
    assert.ok(res.data.token);
    assert.equal(res.data.user.role, 'admin');
    assert.equal(res.data.user.email, TEST_ADMIN_EMAIL);

    // Verify admin profile returned
    assert.ok(res.data.profile);
    assert.equal(res.data.profile.designation, 'Senior Academic Coordinator');
  });

  // 24. Super Admin Google account resolution
  await t.test('24. Super Admin Google account resolution', async () => {
    const res = await api('/api/auth/google', {
      method: 'POST',
      body: {
        idToken: `mock-google-token:${SUPER_ADMIN_GOOGLE_UID}:${SUPER_ADMIN_EMAIL}:Dr. Vikram Malhotra`
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.status, 'LINKED');
    assert.ok(res.data.token);
    assert.equal(res.data.user.email, SUPER_ADMIN_EMAIL);

    // Verify Super Admin token can access Super Admin endpoints
    const adminCheckRes = await api('/api/admins', {
      headers: { Authorization: `Bearer ${res.data.token}` }
    });
    assert.equal(adminCheckRes.status, 200);
    assert.equal(adminCheckRes.data.success, true);
    assert.ok(Array.isArray(adminCheckRes.data.data));
  });

  // 25. Cross-account access prevention
  await t.test('25. Cross-account access prevention', async () => {
    // Student token cannot access institutional administrative fees list
    const feeRes = await api('/api/fees', {
      headers: { Authorization: `Bearer ${activatedStudentToken}` }
    });
    assert.equal(feeRes.status, 403);
    assert.equal(feeRes.data.success, false);

    // Student token cannot access another student's private doubt image
    // (create a dummy doubt for another student)
    const doubtId = 'doubt-other-student-999';
    run('DELETE FROM doubts WHERE id = ?', [doubtId]);
    run(
      `INSERT INTO doubts (id, student_id, batch_id, subject_id, title, note, image_url, status)
       VALUES (?, 'user-student-02', 'batch-pcb-2027-b', 'sub-phy-12', 'Private Question', 'Details', 'doubts/private-diagram.png', 'open')`,
      [doubtId]
    );

    const doubtImgRes = await api(`/api/doubts/${doubtId}/image-url`, {
      headers: { Authorization: `Bearer ${activatedStudentToken}` }
    });
    // Rejected because doubt belongs to user-student-02, not user-stu-step12
    assert.equal(doubtImgRes.status, 403);
    assert.equal(doubtImgRes.data.success, false);
  });
});
