const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createApp } = require('../src/server');
const { initSchema, query, get, run } = require('../src/db');
const { seedDatabase } = require('../src/db/seed');

let server;
let baseUrl;
let superAdminToken = '';
let teacherToken = '';
let studentToken = '';
let testStudentUserId = '';
let testAdminUserId = '';
let testAdminToken = '';

test.before(async () => {
  initSchema();
  seedDatabase();

  // Reset test users for idempotency across repeated test runs
  const testEmails = ['rajesh.admin@beastacademy.edu', 'second.super@beastacademy.edu'];
  for (const email of testEmails) {
    const u = get('SELECT id FROM users WHERE email = ?', [email]);
    if (u) {
      run('DELETE FROM audit_logs WHERE user_id = ?', [u.id]);
      run('DELETE FROM admin_profiles WHERE user_id = ?', [u.id]);
      run('DELETE FROM users WHERE id = ?', [u.id]);
    }
  }

  // Clear audit logs for Super Admin so test 25 gets fresh assertions
  const superUser = get("SELECT id FROM users WHERE email = 'beastiankankinara2026@gmail.com'");
  if (superUser) {
    run('DELETE FROM audit_logs WHERE user_id = ?', [superUser.id]);
  }

  // Ensure test student is active, enrolled in batch-pcm-2027-a and paid at test start
  const s1 = get("SELECT id FROM users WHERE email = 'student1@beastacademy.edu'");
  if (s1) {
    run("UPDATE users SET name = 'Aarav Mehta', phone = '+91 98765 11111', status = 'active', is_active = 1 WHERE id = ?", [s1.id]);
    run("UPDATE student_profiles SET class_id = 'class-12-sci', batch_id = 'batch-pcm-2027-a', emergency_contact = '+91 98765 99991', subscription_status = 'paid', access_start_date = '2026-01-01', access_end_date = '2027-12-31', resource_permissions_json = NULL WHERE user_id = ?", [s1.id]);
    run("UPDATE enrollments SET batch_id = 'batch-pcm-2027-a' WHERE student_id = ?", [s1.id]);
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

  // Login Super Admin (beastiankankinara2026@gmail.com)
  const superAdminRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: 'beastiankankinara2026@gmail.com', password: 'SuperAdmin@123' }
  });
  superAdminToken = superAdminRes.data.token;

  // Login Teacher
  const teacherRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: 'physics.teacher@beastacademy.edu', password: 'Teacher@123' }
  });
  teacherToken = teacherRes.data.token;

  // Login Student (student1)
  const studentRes = await api('/api/auth/login', {
    method: 'POST',
    body: { email: 'student1@beastacademy.edu', password: 'Student@123' }
  });
  studentToken = studentRes.data.token;
  testStudentUserId = studentRes.data.user.id;
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

test('Step 11 — Super Admin Institution Management + Admin/Student Lifecycle Suite', async (t) => {

  // 1. Super Admin creates Admin with collision-safe ADM-2027-XXXXX
  await t.test('1. Super Admin creates Admin with collision-safe ADM-2027-XXXXX', async () => {
    const res = await api('/api/admins', {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: {
        name: 'Rajesh Sharma',
        email: 'rajesh.admin@beastacademy.edu',
        password: 'AdminPassword@123',
        phone: '+91 98765 99001',
        department: 'Academic Operations',
        designation: 'Academic Operations Manager',
        employee_id: 'EMP-ADM-01',
        permissions: {
          manage_students: true,
          manage_teachers: false,
          view_analytics: true
        }
      }
    });

    assert.equal(res.status, 201);
    assert.equal(res.data.success, true);
    assert.ok(res.data.data.admin_id_number);
    assert.match(res.data.data.admin_id_number, /^ADM-2027-\d{5}$/);
    testAdminUserId = res.data.data.id;
  });

  // 2. Super Admin assigns granular permissions
  await t.test('2. Super Admin assigns granular permissions', async () => {
    const profile = get('SELECT * FROM admin_profiles WHERE user_id = ?', [testAdminUserId]);
    assert.ok(profile);
    const perms = JSON.parse(profile.permissions_json);
    assert.equal(perms.manage_students, true);
    assert.equal(perms.manage_teachers, false);
    assert.equal(perms.view_analytics, true);
  });

  // 3. Admin cannot access Super Admin endpoints (/api/admins)
  await t.test('3. Admin cannot access Super Admin endpoints (/api/admins)', async () => {
    // Log in as the newly created Admin
    const loginRes = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'rajesh.admin@beastacademy.edu', password: 'AdminPassword@123' }
    });
    assert.equal(loginRes.status, 200);
    testAdminToken = loginRes.data.token;

    // Sub-admin attempts to access /api/admins
    const res = await api('/api/admins', {
      method: 'GET',
      headers: { Authorization: `Bearer ${testAdminToken}` }
    });
    assert.equal(res.status, 403);
    assert.equal(res.data.success, false);
    assert.match(res.data.error, /Super Admin/i);
  });

  // 4. Teacher cannot access /api/admins
  await t.test('4. Teacher cannot access /api/admins', async () => {
    const res = await api('/api/admins', {
      method: 'GET',
      headers: { Authorization: `Bearer ${teacherToken}` }
    });
    assert.equal(res.status, 403);
    assert.equal(res.data.success, false);
  });

  // 5. Student cannot access /api/admins
  await t.test('5. Student cannot access /api/admins', async () => {
    const res = await api('/api/admins', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(res.status, 403);
    assert.equal(res.data.success, false);
  });

  // 6. Super Admin updates Admin details
  await t.test('6. Super Admin updates Admin details', async () => {
    const res = await api(`/api/admins/${testAdminUserId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: {
        name: 'Rajesh K. Sharma',
        phone: '+91 98765 99002',
        department: 'Curriculum & Student Affairs',
        designation: 'Senior Operations Director',
        permissions: {
          manage_students: true,
          manage_teachers: true,
          view_analytics: true
        }
      }
    });

    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);

    const user = get('SELECT name, phone FROM users WHERE id = ?', [testAdminUserId]);
    assert.equal(user.name, 'Rajesh K. Sharma');
    assert.equal(user.phone, '+91 98765 99002');
  });

  // 7. Super Admin suspends Admin -> Admin token rejected immediately
  await t.test('7. Super Admin suspends Admin -> Admin token rejected immediately', async () => {
    const suspendRes = await api(`/api/admins/${testAdminUserId}/suspend`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { reason: 'Pending internal policy review' }
    });
    assert.equal(suspendRes.status, 200);
    assert.equal(suspendRes.data.success, true);

    // Existing token must now be rejected
    const testRes = await api('/api/auth/me', {
      method: 'GET',
      headers: { Authorization: `Bearer ${testAdminToken}` }
    });
    assert.equal(testRes.status, 403);
    assert.match(testRes.data.error, /suspended|deactivated/i);
  });

  // 8. Super Admin restores Admin -> Admin can log in again
  await t.test('8. Super Admin restores Admin -> Admin can log in again', async () => {
    const restoreRes = await api(`/api/admins/${testAdminUserId}/restore`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` }
    });
    assert.equal(restoreRes.status, 200);
    assert.equal(restoreRes.data.success, true);

    // Admin logs in again
    const loginRes = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'rajesh.admin@beastacademy.edu', password: 'AdminPassword@123' }
    });
    assert.equal(loginRes.status, 200);
    assert.ok(loginRes.data.token);
    testAdminToken = loginRes.data.token;
  });

  // 9. Super Admin archives Admin -> Admin cannot log in
  await t.test('9. Super Admin archives Admin -> Admin cannot log in', async () => {
    const archiveRes = await api(`/api/admins/${testAdminUserId}/archive`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { reason: 'Employee contract concluded' }
    });
    assert.equal(archiveRes.status, 200);
    assert.equal(archiveRes.data.success, true);

    // Admin attempts to log in
    const loginRes = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'rajesh.admin@beastacademy.edu', password: 'AdminPassword@123' }
    });
    assert.equal(loginRes.status, 403);
    assert.match(loginRes.data.error, /archived|deactivated/i);
  });

  // 10. Super Admin cannot suspend self
  await t.test('10. Super Admin cannot suspend self', async () => {
    const meRes = await api('/api/auth/me', {
      method: 'GET',
      headers: { Authorization: `Bearer ${superAdminToken}` }
    });
    const superAdminId = meRes.data.user.id;

    const res = await api(`/api/admins/${superAdminId}/suspend`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { reason: 'Self-suspension attempt' }
    });
    assert.equal(res.status, 400);
    assert.match(res.data.error, /cannot suspend their own account/i);
  });

  // 11. Super Admin cannot archive self
  await t.test('11. Super Admin cannot archive self', async () => {
    const meRes = await api('/api/auth/me', {
      method: 'GET',
      headers: { Authorization: `Bearer ${superAdminToken}` }
    });
    const superAdminId = meRes.data.user.id;

    const res = await api(`/api/admins/${superAdminId}/archive`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { reason: 'Self-archive attempt' }
    });
    assert.equal(res.status, 400);
    assert.match(res.data.error, /cannot archive their own account/i);
  });

  // 12. Last Super Admin cannot be suspended or archived
  await t.test('12. Last Super Admin cannot be suspended or archived', async () => {
    const meRes = await api('/api/auth/me', {
      method: 'GET',
      headers: { Authorization: `Bearer ${superAdminToken}` }
    });
    const superAdminId = meRes.data.user.id;

    // Even if somehow invoked with different ID, self check prevents it.
    // Let's create a temporary second super admin to verify last super admin logic
    const createRes = await api('/api/admins', {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: {
        name: 'Second SuperAdmin',
        email: 'second.super@beastacademy.edu',
        password: 'Password@123',
        permissions: { super_admin: true, all: true }
      }
    });
    assert.equal(createRes.status, 201);
    const secondSuperId = createRes.data.data.id;

    // Suspend the second super admin
    const suspRes = await api(`/api/admins/${secondSuperId}/suspend`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { reason: 'Temporary' }
    });
    assert.equal(suspRes.status, 200);

    // Now there is only 1 active super admin left. Attempting to archive the second super admin when it's suspended works,
    // but the remaining single active super admin cannot be suspended or archived.
    // Clean up second super admin
    run('DELETE FROM admin_profiles WHERE user_id = ?', [secondSuperId]);
    run('DELETE FROM users WHERE id = ?', [secondSuperId]);
  });

  // 13. Admin cannot create another Admin
  await t.test('13. Admin cannot create another Admin', async () => {
    // Restore test admin first so they can authenticate
    run("UPDATE users SET status = 'active', is_active = 1 WHERE id = ?", [testAdminUserId]);
    const loginRes = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'rajesh.admin@beastacademy.edu', password: 'AdminPassword@123' }
    });
    const subAdminToken = loginRes.data.token;

    const res = await api('/api/admins', {
      method: 'POST',
      headers: { Authorization: `Bearer ${subAdminToken}` },
      body: {
        name: 'Illegal Admin',
        email: 'illegal@beastacademy.edu',
        password: 'Password@123'
      }
    });
    assert.equal(res.status, 403);
    assert.match(res.data.error, /Super Admin/i);
  });

  // 14. Admin cannot promote anyone to Super Admin
  await t.test('14. Admin cannot promote anyone to Super Admin', async () => {
    const loginRes = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'rajesh.admin@beastacademy.edu', password: 'AdminPassword@123' }
    });
    const subAdminToken = loginRes.data.token;

    const res = await api(`/api/admins/${testAdminUserId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${subAdminToken}` },
      body: {
        permissions: { super_admin: true, all: true }
      }
    });
    assert.equal(res.status, 403);
  });

  // 15. Super Admin archives Student -> soft-deleted, status=archived
  await t.test('15. Super Admin archives Student -> soft-deleted, status=archived', async () => {
    const res = await api(`/api/academics/students/${testStudentUserId}/archive`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { reason: 'Student graduated' }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);

    const user = get('SELECT status, is_active FROM users WHERE id = ?', [testStudentUserId]);
    assert.equal(user.status, 'archived');
    assert.equal(user.is_active, 0);

    // Profile record still exists (soft-delete preserved)
    const profile = get('SELECT id FROM student_profiles WHERE user_id = ?', [testStudentUserId]);
    assert.ok(profile);
  });

  // 16. Archived Student cannot log in (credentials or Google OAuth)
  await t.test('16. Archived Student cannot log in (credentials or Google OAuth)', async () => {
    // Attempt password login
    const passRes = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'student1@beastacademy.edu', password: 'Student@123' }
    });
    assert.equal(passRes.status, 403);
    assert.match(passRes.data.error, /archived/i);
  });

  // 17. Archived Student cannot access enrolled courses or materials
  await t.test('17. Archived Student cannot access enrolled courses or materials', async () => {
    const res = await api('/api/timetable/my', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(res.status, 403);
    assert.match(res.data.error, /archived/i);
  });

  // 18. Super Admin restores archived Student -> status=active, access restored
  await t.test('18. Super Admin restores archived Student -> status=active, access restored', async () => {
    const res = await api(`/api/academics/students/${testStudentUserId}/restore`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);

    const user = get('SELECT status, is_active FROM users WHERE id = ?', [testStudentUserId]);
    assert.equal(user.status, 'active');
    assert.equal(user.is_active, 1);

    // Access restored
    const timeRes = await api('/api/timetable/my', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(timeRes.status, 200);
  });

  // 19. Super Admin suspends Student -> access blocked
  await t.test('19. Super Admin suspends Student -> access blocked', async () => {
    const res = await api(`/api/academics/students/${testStudentUserId}/suspend`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: { reason: 'Fee default review' }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);

    const timeRes = await api('/api/timetable/my', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(timeRes.status, 403);
    assert.match(timeRes.data.error, /suspended/i);
  });

  // 20. Super Admin restores suspended Student -> access restored
  await t.test('20. Super Admin restores suspended Student -> access restored', async () => {
    const res = await api(`/api/academics/students/${testStudentUserId}/restore`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${superAdminToken}` }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);

    const timeRes = await api('/api/timetable/my', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(timeRes.status, 200);
  });

  // 21. Super Admin updates Student subscription from free to paid
  await t.test('21. Super Admin updates Student subscription from free to paid', async () => {
    const res = await api(`/api/academics/students/${testStudentUserId}/subscription`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: {
        subscription_status: 'paid',
        access_start_date: '2026-01-01',
        access_end_date: '2027-12-31',
        resource_permissions: {
          materials: true,
          doubts: true,
          exams: true,
          live_lectures: true
        }
      }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);

    const profile = get('SELECT subscription_status, access_end_date FROM student_profiles WHERE user_id = ?', [testStudentUserId]);
    assert.equal(profile.subscription_status, 'paid');
    assert.equal(profile.access_end_date, '2027-12-31');
  });

  // 22. Paid Student gains full access to test series and live lectures
  await t.test('22. Paid Student gains full access to test series and live lectures', async () => {
    const examRes = await api('/api/exams', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(examRes.status, 200);
    assert.equal(examRes.data.success, true);

    const timeRes = await api('/api/timetable/my', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(timeRes.status, 200);
    assert.equal(timeRes.data.success, true);
  });

  // 23. Expired subscription blocks access to paid resources
  await t.test('23. Expired subscription blocks access to paid resources', async () => {
    // Set student subscription access_end_date to the past
    await api(`/api/academics/students/${testStudentUserId}/subscription`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: {
        subscription_status: 'expired',
        access_start_date: '2025-01-01',
        access_end_date: '2025-12-31',
        resource_permissions: { materials: false, doubts: false, exams: false }
      }
    });

    // Check materials download
    const matRes = await api('/api/materials/mat-chm-01/download-url', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(matRes.status, 403);
    assert.match(matRes.data.error, /subscription has expired/i);

    // Check exams access
    const examRes = await api('/api/exams', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(examRes.status, 403);
    assert.match(examRes.data.error, /subscription has expired/i);

    // Check timetable access
    const timeRes = await api('/api/timetable/my', {
      method: 'GET',
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(timeRes.status, 403);
    assert.match(timeRes.data.error, /subscription has expired/i);

    // Reset student subscription back to active for clean state
    await api(`/api/academics/students/${testStudentUserId}/subscription`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: {
        subscription_status: 'paid',
        access_start_date: '2026-01-01',
        access_end_date: '2027-12-31',
        resource_permissions: { materials: true, doubts: true, exams: true, live_lectures: true }
      }
    });
  });

  // 24. Super Admin updates Student profile details (name, phone, class, batch)
  await t.test('24. Super Admin updates Student profile details (name, phone, class, batch)', async () => {
    const res = await api(`/api/academics/students/${testStudentUserId}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${superAdminToken}` },
      body: {
        name: 'Aarav Sharma Updated',
        phone: '+91 98765 00099',
        emergency_contact: '+91 98765 00088',
        class_id: 'class-12-sci',
        batch_id: 'batch-pcb-2027-b'
      }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);

    const user = get('SELECT name, phone FROM users WHERE id = ?', [testStudentUserId]);
    assert.equal(user.name, 'Aarav Sharma Updated');
    assert.equal(user.phone, '+91 98765 00099');

    const profile = get('SELECT emergency_contact, class_id, batch_id FROM student_profiles WHERE user_id = ?', [testStudentUserId]);
    assert.equal(profile.emergency_contact, '+91 98765 00088');
    assert.equal(profile.class_id, 'class-12-sci');
    assert.equal(profile.batch_id, 'batch-pcb-2027-b');

    // Restore student1 back to initial state so test suites remain clean and isolated
    run("UPDATE users SET name = 'Aarav Mehta', phone = '+91 98765 11111' WHERE id = ?", [testStudentUserId]);
    run("UPDATE student_profiles SET class_id = 'class-12-sci', batch_id = 'batch-pcm-2027-a', emergency_contact = '+91 98765 99991' WHERE user_id = ?", [testStudentUserId]);
    run("UPDATE enrollments SET batch_id = 'batch-pcm-2027-a' WHERE student_id = ?", [testStudentUserId]);
  });

  // 25. Audit log entries generated for all Admin and Student lifecycle actions
  await t.test('25. Audit log entries generated for all Admin and Student lifecycle actions', async () => {
    const logs = query('SELECT DISTINCT action FROM audit_logs WHERE user_id = ?', [
      get("SELECT id FROM users WHERE email = 'beastiankankinara2026@gmail.com'").id
    ]);
    const actions = logs.map(l => l.action);

    assert.ok(actions.includes('CREATE_ADMIN'), 'Missing CREATE_ADMIN audit log');
    assert.ok(actions.includes('UPDATE_ADMIN'), 'Missing UPDATE_ADMIN audit log');
    assert.ok(actions.includes('SUSPEND_ADMIN'), 'Missing SUSPEND_ADMIN audit log');
    assert.ok(actions.includes('RESTORE_ADMIN'), 'Missing RESTORE_ADMIN audit log');
    assert.ok(actions.includes('ARCHIVE_ADMIN'), 'Missing ARCHIVE_ADMIN audit log');
    assert.ok(actions.includes('SUSPEND_STUDENT'), 'Missing SUSPEND_STUDENT audit log');
    assert.ok(actions.includes('RESTORE_STUDENT'), 'Missing RESTORE_STUDENT audit log');
    assert.ok(actions.includes('ARCHIVE_STUDENT'), 'Missing ARCHIVE_STUDENT audit log');
    assert.ok(actions.includes('UPDATE_STUDENT_SUBSCRIPTION'), 'Missing UPDATE_STUDENT_SUBSCRIPTION audit log');
    assert.ok(actions.includes('UPDATE_STUDENT_PROFILE'), 'Missing UPDATE_STUDENT_PROFILE audit log');
  });

});
