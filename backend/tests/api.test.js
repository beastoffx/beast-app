const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createApp } = require('../src/server');
const { initSchema } = require('../src/db');
const { seedDatabase } = require('../src/db/seed');

let server;
let baseUrl;
let adminToken = '';
let teacherToken = '';
let studentToken = '';

test.before(async () => {
  // Ensure schema and seed data are in place
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
});

test.after(async () => {
  if (server) {
    await new Promise((resolve) => server.close(resolve));
  }
});

// Helper for HTTP requests
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

test('1. Health Check Endpoint', async () => {
  const res = await api('/api/health');
  assert.equal(res.status, 200);
  assert.equal(res.data.status, 'UP');
  assert.equal(res.data.app, 'B.E.A.S.T ACADEMY Production API');
});

test('2. Authentication Workflows', async (t) => {
  await t.test('Admin Login Success', async () => {
    const res = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'admin@beastacademy.edu', password: 'Admin@123' }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.user.role, 'admin');
    assert.ok(res.data.token);
    adminToken = res.data.token;
  });

  await t.test('Teacher Login Success', async () => {
    const res = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'physics.teacher@beastacademy.edu', password: 'Teacher@123' }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.user.role, 'teacher');
    teacherToken = res.data.token;
  });

  await t.test('Student Login Success', async () => {
    const res = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'student1@beastacademy.edu', password: 'Student@123' }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.equal(res.data.user.role, 'student');
    studentToken = res.data.token;
  });

  await t.test('Invalid Password Rejection', async () => {
    const res = await api('/api/auth/login', {
      method: 'POST',
      body: { email: 'admin@beastacademy.edu', password: 'WrongPassword' }
    });
    assert.equal(res.status, 401);
    assert.equal(res.data.success, false);
  });
});

test('3. RBAC Server-Side Enforcement', async (t) => {
  await t.test('Student Cannot Access Admin Dashboard', async () => {
    const res = await api('/api/dashboard/admin', {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(res.status, 403);
    assert.equal(res.data.success, false);
  });

  await t.test('Student Cannot Create Timetable Slot', async () => {
    const res = await api('/api/timetable', {
      method: 'POST',
      headers: { Authorization: `Bearer ${studentToken}` },
      body: { batch_id: 'batch-pcm-2027-a', subject_id: 'sub-phy-12' }
    });
    assert.equal(res.status, 403);
  });

  await t.test('Admin Can Access Admin Dashboard', async () => {
    const res = await api('/api/dashboard/admin', {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
    assert.ok(res.data.data.actionableToday);
  });
});

test('4. Timetable Scheduling & Collision Prevention', async (t) => {
  await t.test('Student Retrieves Personalized Schedule', async () => {
    const res = await api('/api/timetable/my', {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.data.data.schedule));
    assert.ok(res.data.data.schedule.length > 0);
  });

  await t.test('Teacher Collision Detection on Double-Booking', async () => {
    // Attempt to book same teacher on Monday (day 1) 08:30 - 10:00
    const res = await api('/api/timetable', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        batch_id: 'batch-pcb-2027-b',
        subject_id: 'sub-phy-12',
        teacher_id: 'user-teacher-phy',
        day_of_week: 1,
        start_time: '08:30',
        end_time: '10:00',
        room_number: 'Hall 3'
      }
    });
    assert.equal(res.status, 409);
    assert.match(res.data.error, /already scheduled/);
  });
});

test('5. Attendance Tracking Workflow', async (t) => {
  await t.test('Teacher Records Batch Attendance', async () => {
    const todayStr = new Date().toISOString().split('T')[0];
    const res = await api('/api/attendance/batch', {
      method: 'POST',
      headers: { Authorization: `Bearer ${teacherToken}` },
      body: {
        batch_id: 'batch-pcm-2027-a',
        subject_id: 'sub-phy-12',
        date: todayStr,
        records: [
          { student_id: 'user-student-01', status: 'present', remarks: 'Good participation' },
          { student_id: 'user-student-02', status: 'late', remarks: 'Traffic delay' }
        ]
      }
    });
    assert.equal(res.status, 200);
    assert.equal(res.data.success, true);
  });

  await t.test('Student Views Attendance Summary & Percentage', async () => {
    const res = await api('/api/attendance/my', {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(res.status, 200);
    assert.ok(res.data.data.overallPercentage >= 0);
    assert.ok(Array.isArray(res.data.data.subjectBreakdown));
  });
});

test('6. Assignments & Submissions Workflow', async (t) => {
  let createdAssignmentId = '';

  await t.test('Teacher Creates Assignment', async () => {
    const res = await api('/api/assignments', {
      method: 'POST',
      headers: { Authorization: `Bearer ${teacherToken}` },
      body: {
        title: 'Electromagnetic Induction Lab Problems',
        subject_id: 'sub-phy-12',
        batch_id: 'batch-pcm-2027-a',
        deadline: '2026-11-01 23:59',
        max_marks: 50,
        description: 'Verify Faraday law calculations from sample coil tests.'
      }
    });
    assert.equal(res.status, 200);
    assert.ok(res.data.id);
    createdAssignmentId = res.data.id;
  });

  await t.test('Student Submits Assignment', async () => {
    const res = await api(`/api/assignments/${createdAssignmentId}/submit`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${studentToken}` },
      body: {
        notes: 'Attached detailed calculations and flux integration steps.',
        file_url: '/uploads/submissions/test_solution.pdf'
      }
    });
    assert.equal(res.status, 200);
  });

  await t.test('Teacher Views Submissions and Grades', async () => {
    const listRes = await api(`/api/assignments/${createdAssignmentId}/submissions`, {
      headers: { Authorization: `Bearer ${teacherToken}` }
    });
    assert.equal(listRes.status, 200);
    assert.ok(listRes.data.data.length > 0);
    const subId = listRes.data.data[0].id;

    const gradeRes = await api(`/api/assignments/submissions/${subId}/grade`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${teacherToken}` },
      body: {
        marks: 49,
        feedback: 'Flawless mathematical reasoning.'
      }
    });
    assert.equal(gradeRes.status, 200);
  });
});

test('7. DoubtDeck Flow: Student Doubts & Teacher Responses', async (t) => {
  let doubtId = '';

  await t.test('Student Captures & Posts Doubt', async () => {
    const res = await api('/api/doubts', {
      method: 'POST',
      headers: { Authorization: `Bearer ${studentToken}` },
      body: {
        subject_id: 'sub-phy-12',
        title: 'Lenz Law in non-inertial frame',
        topic: 'Electromagnetic Induction',
        note: 'How does magnetic force transformation affect induced EMF observed in rotating disk frames?',
        priority: 'high'
      }
    });
    assert.equal(res.status, 200);
    assert.ok(res.data.id);
    doubtId = res.data.id;
  });

  await t.test('Teacher Responds to Doubt', async () => {
    const res = await api(`/api/doubts/${doubtId}/respond`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${teacherToken}` },
      body: {
        message: 'In rotating frames, Coriolis acceleration must be added alongside the Lorentz force (q v x B).'
      }
    });
    assert.equal(res.status, 200);
  });

  await t.test('Student Marks Doubt Resolved', async () => {
    const res = await api(`/api/doubts/${doubtId}/resolve`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${studentToken}` },
      body: { is_resolved: true }
    });
    assert.equal(res.status, 200);
  });
});

test('8. Fee Ledger & Privacy Protection', async (t) => {
  await t.test('Student Views Fee Ledger', async () => {
    const res = await api('/api/fees/my', {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.data.data.fees));
  });

  await t.test('Student Cannot Access All Institutional Fee Records', async () => {
    const res = await api('/api/fees', {
      headers: { Authorization: `Bearer ${studentToken}` }
    });
    assert.equal(res.status, 403);
  });
});

test('9. AI Layer Governance (Section 23 Compliance)', async () => {
  const res = await api('/api/ai/status', {
    headers: { Authorization: `Bearer ${studentToken}` }
  });
  assert.equal(res.status, 200);
  assert.equal(res.data.data.enabled, false);
  assert.equal(res.data.data.activeProvider, 'disabled');
});
