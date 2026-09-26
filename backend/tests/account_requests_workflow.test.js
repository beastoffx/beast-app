process.env.NODE_ENV = 'test';
const config = require('../src/config');
config.nodeEnv = 'test';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createApp } = require('../src/server');
const { initSchema, query, get, run } = require('../src/db');
const { seedDatabase } = require('../src/db/seed');

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

async function api(path, options = {}) {
  const url = `${baseUrl}${path}`;
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  const res = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  const data = await res.json();
  return { status: res.status, data };
}

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
    body: { email: CANONICAL_SUPER_ADMIN_EMAIL, password: 'Jeet@2026' }
  });
  superAdminToken = superRes.data.token;

  // Login Admin
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

test('Multi-tier Account Onboarding & Verification Workflow Suite', async (t) => {
  let studentRequestId = '';
  let teacherRequestId = '';
  let adminRequestId = '';

  const testStudentEmail = 'applicant.student@example.com';
  const testTeacherEmail = 'applicant.teacher@example.com';
  const testAdminEmail = 'applicant.admin@example.com';

  // Clean test records
  run('DELETE FROM account_requests WHERE email IN (?, ?, ?)', [testStudentEmail, testTeacherEmail, testAdminEmail]);

  // 1. Student submits onboarding request
  await t.test('1. Student submits onboarding request -> status PENDING_TEACHER_REVIEW', async () => {
    const res = await api('/api/requests', {
      method: 'POST',
      body: {
        name: 'Applicant Student',
        email: testStudentEmail,
        phone: '+91 99999 88881',
        requested_role: 'student',
        target_class_id: 'class-12-sci',
        target_batch_id: 'batch-pcm-2027-a',
        target_session_id: 'session-2026-2027',
        notes: 'Interested in IIT-JEE prep'
      }
    });

    assert.equal(res.status, 201);
    assert.equal(res.data.success, true);
    assert.equal(res.data.data.status, 'PENDING_TEACHER_REVIEW');
    studentRequestId = res.data.data.id;
  });

  // 2. Duplicate submission blocked
  await t.test('2. Duplicate submission for same email blocked with 409', async () => {
    const res = await api('/api/requests', {
      method: 'POST',
      body: {
        name: 'Applicant Student Again',
        email: testStudentEmail,
        requested_role: 'student',
        target_class_id: 'class-12-sci',
        target_batch_id: 'batch-pcm-2027-a',
        target_session_id: 'session-2026-2027'
      }
    });

    assert.equal(res.status, 409);
    assert.equal(res.data.success, false);
  });

  // 3. Public status check
  await t.test('3. Public status check returns current review status', async () => {
    const res = await api(`/api/requests/status?email=${encodeURIComponent(testStudentEmail)}`);
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.data.status, 'PENDING_TEACHER_REVIEW');
    assert.equal(res.data.data.class_name, 'Class 12');
  });

  // 4. Student token cannot list or review requests
  await t.test('4. Student token cannot access requests endpoints (403)', async () => {
    const listRes = await api('/api/requests', {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(listRes.status, 403);

    const reviewRes = await api(`/api/requests/${studentRequestId}/review`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${studentToken}` },
      body: { action: 'approve' }
    });
    assert.equal(reviewRes.status, 403);
  });

  // 5. Teacher lists student requests
  await t.test('5. Teacher lists student requests in PENDING_TEACHER_REVIEW', async () => {
    const res = await api('/api/requests', {
      headers: { Authorization: `Bearer ${teacherToken}` }
    });
    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.data.data));
    const found = res.data.data.find(r => r.id === studentRequestId);
    assert.ok(found, 'Student request must appear in teacher review queue');
  });

  // 6. Teacher reviews and approves Student request -> advances to PENDING_ADMIN_REVIEW
  await t.test('6. Teacher approves Student request -> status advances to PENDING_ADMIN_REVIEW', async () => {
    const res = await api(`/api/requests/${studentRequestId}/review`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${teacherToken}` },
      body: { action: 'approve', reviewNotes: 'Verified prerequisite academic background' }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.data.status, 'PENDING_ADMIN_REVIEW');
  });

  // 7. Teacher cannot review at Admin stage
  await t.test('7. Teacher cannot re-review or approve request at Admin stage (403)', async () => {
    const res = await api(`/api/requests/${studentRequestId}/review`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${teacherToken}` },
      body: { action: 'approve' }
    });
    assert.equal(res.status, 403);
  });

  // 8. Admin reviews and approves Student request -> advances to PENDING_SUPER_ADMIN_REVIEW
  await t.test('8. Admin approves Student request -> status advances to PENDING_SUPER_ADMIN_REVIEW', async () => {
    const res = await api(`/api/requests/${studentRequestId}/review`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { action: 'approve', reviewNotes: 'Verified fee clearance and institutional admission quota' }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.data.status, 'PENDING_SUPER_ADMIN_REVIEW');
  });

  // 9. Admin cannot perform final Super Admin activation
  await t.test('9. Admin cannot perform Super Admin final activation (403)', async () => {
    const res = await api(`/api/requests/${studentRequestId}/review`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { action: 'approve' }
    });
    assert.equal(res.status, 403);
  });

  // 10. Super Admin final approval -> Collision-safe Student ID generated & account activated atomically
  await t.test('10. Super Admin approves Student request -> Generates BST-2027-XXXXX and activates account', async () => {
    const res = await api(`/api/requests/${studentRequestId}/review`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { action: 'approve', reviewNotes: 'Final executive authorization granted' }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.data.status, 'APPROVED');
    assert.ok(res.data.data.generated_student_id.startsWith('BST-2027-'));
    assert.ok(res.data.data.created_user_id);

    // Verify user and profile records in database
    const createdUser = get('SELECT * FROM users WHERE email = ?', [testStudentEmail]);
    assert.ok(createdUser, 'Activated user record must exist in DB');
    assert.equal(createdUser.role, 'student');
    assert.equal(createdUser.status, 'active');
    assert.equal(createdUser.is_active, 1);

    const studentProfile = get('SELECT * FROM student_profiles WHERE user_id = ?', [createdUser.id]);
    assert.ok(studentProfile, 'Student profile must exist in DB');
    assert.equal(studentProfile.student_id_number, res.data.data.generated_student_id);
    assert.equal(studentProfile.subscription_status, 'paid');

    const enrollment = get('SELECT * FROM enrollments WHERE student_id = ?', [createdUser.id]);
    assert.ok(enrollment, 'Enrollment must exist in DB');
  });

  // 11. Teacher onboarding flow: starts at PENDING_ADMIN_REVIEW -> Admin approves -> Super Admin activates
  await t.test('11. Teacher onboarding flow: Admin approves -> Super Admin activates', async () => {
    const submitRes = await api('/api/requests', {
      method: 'POST',
      body: {
        name: 'Applicant Teacher',
        email: testTeacherEmail,
        phone: '+91 99999 88882',
        requested_role: 'teacher',
        qualification: 'M.Sc. Mathematics',
        department: 'Mathematics'
      }
    });
    assert.equal(submitRes.status, 201);
    teacherRequestId = submitRes.data.data.id;
    assert.equal(submitRes.data.data.status, 'PENDING_ADMIN_REVIEW');

    // Admin approves teacher request
    const adminApproveRes = await api(`/api/requests/${teacherRequestId}/review`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { action: 'approve', reviewNotes: 'Interview cleared' }
    });
    assert.equal(adminApproveRes.status, 200);
    assert.equal(adminApproveRes.data.data.status, 'PENDING_SUPER_ADMIN_REVIEW');

    // Super Admin approves teacher request
    const superApproveRes = await api(`/api/requests/${teacherRequestId}/review`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { action: 'approve', reviewNotes: 'Faculty appointment approved' }
    });
    assert.equal(superApproveRes.status, 200);
    assert.equal(superApproveRes.data.data.status, 'APPROVED');

    const createdTeacher = get('SELECT * FROM users WHERE email = ?', [testTeacherEmail]);
    assert.ok(createdTeacher);
    assert.equal(createdTeacher.role, 'teacher');
    assert.equal(createdTeacher.status, 'active');

    const teacherProfile = get('SELECT * FROM teacher_profiles WHERE user_id = ?', [createdTeacher.id]);
    assert.ok(teacherProfile);
    assert.ok(teacherProfile.employee_code.startsWith('TCH-2027-'));
  });

  // 12. Admin onboarding flow: starts at PENDING_SUPER_ADMIN_REVIEW -> Super Admin activates
  await t.test('12. Admin onboarding flow: Super Admin activates directly', async () => {
    const submitRes = await api('/api/requests', {
      method: 'POST',
      body: {
        name: 'Applicant Admin',
        email: testAdminEmail,
        phone: '+91 99999 88883',
        requested_role: 'admin',
        department: 'Academic Operations'
      }
    });
    assert.equal(submitRes.status, 201);
    adminRequestId = submitRes.data.data.id;
    assert.equal(submitRes.data.data.status, 'PENDING_SUPER_ADMIN_REVIEW');

    // Super Admin approves admin request
    const superApproveRes = await api(`/api/requests/${adminRequestId}/review`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { action: 'approve', reviewNotes: 'Administrative clearance confirmed' }
    });
    assert.equal(superApproveRes.status, 200);
    assert.equal(superApproveRes.data.data.status, 'APPROVED');

    const createdAdmin = get('SELECT * FROM users WHERE email = ?', [testAdminEmail]);
    assert.ok(createdAdmin);
    assert.equal(createdAdmin.role, 'admin');
    assert.equal(createdAdmin.status, 'active');

    const adminProfile = get('SELECT * FROM admin_profiles WHERE user_id = ?', [createdAdmin.id]);
    assert.ok(adminProfile);
    assert.ok(adminProfile.admin_id_number.startsWith('ADM-2027-'));
  });

  // Cleanup test records
  run('DELETE FROM users WHERE email IN (?, ?, ?)', [testStudentEmail, testTeacherEmail, testAdminEmail]);
  run('DELETE FROM account_requests WHERE email IN (?, ?, ?)', [testStudentEmail, testTeacherEmail, testAdminEmail]);
});
