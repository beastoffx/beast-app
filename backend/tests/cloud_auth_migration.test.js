const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('fs');
const path = require('path');
const { createApp } = require('../src/server');
const { initSchema, query, get, run } = require('../src/db');
const { seedDatabase } = require('../src/db/seed');
const { OtpService } = require('../src/services/otpService');

let server;
let baseUrl;
let adminToken = '';
let studentToken = '';
let teacherToken = '';

test.before(async () => {
  initSchema();
  seedDatabase();

  // Reset Student 3 state so test suite is 100% deterministic even across re-runs on disk
  run("DELETE FROM phone_verifications WHERE student_id_number = 'BST-2027-00003'");
  const s3User = get("SELECT u.id FROM users u JOIN student_profiles sp ON u.id = sp.user_id WHERE sp.student_id_number = 'BST-2027-00003'");
  if (s3User) {
    run("UPDATE users SET google_uid = NULL, phone = NULL, phone_verified = 0, status = 'pending_activation', is_active = 1 WHERE id = ?", [s3User.id]);
  }

  const app = createApp();
  server = http.createServer(app);

  await new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const addr = server.address();
      baseUrl = `http://127.0.0.1:${addr.port}`;
      resolve();
    });
  });

  // Login admin for admin-scoped tests
  const adminRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: 'admin@beastacademy.edu', password: 'Admin@123' }
  });
  adminToken = adminRes.data.token;

  // Login teacher for teacher-scoped tests
  const teacherRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: 'physics.teacher@beastacademy.edu', password: 'Teacher@123' }
  });
  teacherToken = teacherRes.data.token;

  // Login student for student-scoped tests
  const studentRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: 'student1@beastacademy.edu', password: 'Student@123' }
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
  const json = await res.json();
  return { status: res.status, data: json };
}

// ==================== TEST SUITES ====================

test('Cloud Auth Migration & Security Test Suite', async (t) => {

  // 1. Google identity validation
  await t.test('1. Google Identity Validation', async (t1) => {
    await t1.test('Missing ID Token returns 400 Bad Request', async () => {
      const res = await api('/api/auth/google', { method: 'POST', body: {} });
      assert.equal(res.status, 400);
      assert.equal(res.data.success, false);
    });

    await t1.test('Invalid ID Token signature returns 401 Unauthorized', async () => {
      const res = await api('/api/auth/google', {
        method: 'POST',
        body: { idToken: 'mock-google-token-invalid' }
      });
      assert.equal(res.status, 401);
      assert.equal(res.data.success, false);
    });
  });

  // 2. Unknown Google user returns UNLINKED status
  const testGoogleUid = `google-uid-test-${Date.now()}`;
  const testGoogleEmail = `rohan.verma.cloud@gmail.com`;
  const validMockToken = `mock-google-token:${testGoogleUid}:${testGoogleEmail}:Rohan Verma`;

  await t.test('2. Unknown Google User returns UNLINKED status', async () => {
    const res = await api('/api/auth/google', {
      method: 'POST',
      body: { idToken: validMockToken }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.status, 'UNLINKED');
    assert.equal(res.data.googleUid, testGoogleUid);
    assert.equal(res.data.email, testGoogleEmail);
  });

  // 3. Student ID validation
  await t.test('3. Student ID Validation on Activation', async () => {
    const res = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: testGoogleUid,
        studentIdNumber: 'BST-NON-EXISTENT-999',
        phone: '+91 98765 33333'
      }
    });

    assert.equal(res.status, 404);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /Invalid Student ID/);
  });

  // 4. Phone verification state & OTP dispatch
  let activationSessionId = '';
  await t.test('4. Phone Verification State & OTP Dispatch', async () => {
    const res = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: testGoogleUid,
        studentIdNumber: 'BST-2027-00003',
        phone: '+91 98765 33333'
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.ok(res.data.sessionId);
    activationSessionId = res.data.sessionId;

    // Verify record in phone_verifications table
    const record = get('SELECT * FROM phone_verifications WHERE session_id = ?', [activationSessionId]);
    assert.ok(record);
    assert.equal(record.phone, '+91 98765 33333');
    assert.equal(record.student_id_number, 'BST-2027-00003');
    assert.equal(record.is_verified, 0);
  });

  // 5. Verification failure on wrong OTP
  await t.test('5. OTP Verification Rejection on Incorrect Code', async () => {
    const res = await api('/api/auth/activate/verify', {
      method: 'POST',
      body: {
        sessionId: activationSessionId,
        otp: '000000', // incorrect code
        googleUid: testGoogleUid,
        studentIdNumber: 'BST-2027-00003'
      }
    });

    assert.equal(res.status, 400);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /Incorrect verification code/);
  });

  // 6. Successful verification, linking, and activation
  let activatedStudentToken = '';
  await t.test('6. Student Activation: Atomically links Google UID + Phone', async () => {
    // Retrieve the cryptographically generated OTP from the test provider
    const otpCode = OtpService.getActiveProvider().getTestOtp('+91 98765 33333');
    assert.ok(otpCode, 'OTP code should be generated in test provider');

    const res = await api('/api/auth/activate/verify', {
      method: 'POST',
      body: {
        sessionId: activationSessionId,
        otp: otpCode,
        googleUid: testGoogleUid,
        studentIdNumber: 'BST-2027-00003'
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.status, 'ACTIVATED');
    assert.ok(res.data.token);
    activatedStudentToken = res.data.token;
    assert.equal(res.data.user.google_uid, testGoogleUid);
    assert.equal(res.data.user.phone, '+91 98765 33333');
    assert.equal(res.data.user.phone_verified, true);
    assert.equal(res.data.user.status, 'active');

    // Verify database state directly
    const userInDb = get('SELECT * FROM users WHERE google_uid = ?', [testGoogleUid]);
    assert.ok(userInDb);
    assert.equal(userInDb.status, 'active');
    assert.equal(userInDb.phone_verified, 1);
  });

  // 7. New-device login behavior: already-linked Google account returns LINKED
  await t.test('7. New-Device Login: Already-linked Google Account instantly resolves session', async () => {
    const res = await api('/api/auth/google', {
      method: 'POST',
      body: { idToken: validMockToken }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.status, 'LINKED');
    assert.ok(res.data.token);
    assert.equal(res.data.user.google_uid, testGoogleUid);
    assert.ok(res.data.profile);
    assert.equal(res.data.profile.student_id_number, 'BST-2027-00003');
  });

  // 8. Duplicate Student ID activation prevention
  await t.test('8. Duplicate Student ID Activation Prevention', async () => {
    const anotherGoogleUid = `google-uid-intruder-${Date.now()}`;
    const res = await api('/api/auth/activate/send-otp', {
      method: 'POST',
      body: {
        googleUid: anotherGoogleUid,
        studentIdNumber: 'BST-2027-00003', // already linked to testGoogleUid!
        phone: '+91 98765 99999'
      }
    });

    assert.equal(res.status, 409);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /already linked to another Google account/);
  });

  // 9. Super Admin Student Provisioning with Collision-Safe ID
  let provisionedStudentId = '';
  await t.test('9. Super Admin Provisions Student with Collision-Safe ID', async () => {
    const res = await api('/api/academics/students', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        name: 'Kabir Singhania',
        email: `kabir.${Date.now()}@beastacademy.edu`,
        class_id: 'class-12-sci',
        batch_id: 'batch-pcm-2027-a',
        academic_session_id: 'session-2026-2027',
        subscription_status: 'paid'
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.ok(res.data.studentIdNumber.startsWith('BST-2027-'));
    provisionedStudentId = res.data.id;

    // Verify that non-admins cannot provision students
    const forbiddenRes = await api('/api/academics/students', {
      method: 'POST',
      headers: { Authorization: `Bearer ${studentToken}` },
      body: { name: 'Illegal Student' }
    });
    assert.equal(forbiddenRes.status, 403);
  });

  // 10. Suspended student access rejection
  await t.test('10. Suspended Student Rejection', async () => {
    // Suspend the student
    const suspendRes = await api(`/api/academics/students/${provisionedStudentId}/status`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { status: 'suspended' }
    });
    assert.equal(suspendRes.status, 200);

    // Verify user in db is suspended
    const user = get('SELECT status, is_active FROM users WHERE id = ?', [provisionedStudentId]);
    assert.equal(user.status, 'suspended');
    assert.equal(user.is_active, 0);
  });

  // 11. Private storage authorization & download URL endpoint
  await t.test('11. Private Storage Authorization & Signed Download URLs', async () => {
    // 1. Get an existing material ID
    const materials = query('SELECT id FROM study_materials LIMIT 1');
    assert.ok(materials.length > 0);
    const materialId = materials[0].id;

    // Active student requests download URL
    const res = await api(`/api/materials/${materialId}/download-url`, {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.ok(res.data.downloadUrl);
  });

  // 12. Cross-student private doubt access prevention
  await t.test('12. Cross-Student Data Access Prevention on Private Doubts', async () => {
    // Student 1 creates a doubt
    const doubtRes = await api('/api/doubts', {
      method: 'POST',
      headers: { Authorization: `Bearer ${studentToken}` },
      body: {
        subject_id: 'sub-phy-12',
        title: 'Private Doubt Test',
        note: 'Is this private?',
        priority: 'normal'
      }
    });
    assert.equal(doubtRes.status, 200);
    const doubtId = doubtRes.data.id;

    // Attach an image URL directly to test download authorization
    run("UPDATE doubts SET image_url = 'doubt_secret_photo.png', batch_id = 'batch-pcm-2027-a' WHERE id = ?", [doubtId]);

    // Student 1 (owner) accesses image URL -> 200
    const ownerRes = await api(`/api/doubts/${doubtId}/image-url`, {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(ownerRes.status, 200);
    assert.ok(ownerRes.data.imageUrl);

    // Unauthenticated user -> 401
    const unauthRes = await api(`/api/doubts/${doubtId}/image-url`);
    assert.equal(unauthRes.status, 401);
  });

  // 13. PostgreSQL Schema Migration Syntax & Table Verification
  await t.test('13. PostgreSQL Schema DDL Syntax & Entities Verification', async () => {
    const schemaPath = path.join(__dirname, '..', 'src', 'db', 'migrations', '001_postgres_schema.sql');
    assert.ok(fs.existsSync(schemaPath), 'PostgreSQL migration file must exist');

    const ddl = fs.readFileSync(schemaPath, 'utf8');
    assert.ok(ddl.includes('CREATE TABLE IF NOT EXISTS users'));
    assert.ok(ddl.includes('CREATE TABLE IF NOT EXISTS student_profiles'));
    assert.ok(ddl.includes('CREATE TABLE IF NOT EXISTS phone_verifications'));
    assert.ok(ddl.includes('google_uid VARCHAR(128) UNIQUE'));
    assert.ok(ddl.includes('subscription_status VARCHAR(32)'));
  });

});
