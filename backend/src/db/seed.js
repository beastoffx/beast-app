const bcrypt = require('bcryptjs');
const { initSchema, run, get, query } = require('./index');

function hashPassword(password) {
  return bcrypt.hashSync(password, 10);
}

function seedDatabase() {
  console.log('[SEED] Initializing schema...');
  initSchema();

  // Check if admin already exists
  const existingAdmin = get('SELECT id FROM users WHERE email = ?', ['admin@beastacademy.edu']);
  if (existingAdmin) {
    console.log('[SEED] Database already seeded. Skipping.');
    return;
  }

  console.log('[SEED] Seeding B.E.A.S.T ACADEMY initial data...');

  // 1. Academic Session
  const sessionId = 'session-2026-2027';
  run(
    `INSERT INTO academic_sessions (id, name, start_date, end_date, is_current)
     VALUES (?, ?, ?, ?, 1)`,
    [sessionId, '2026-2027', '2026-04-01', '2027-03-31']
  );

  // 2. Classes
  const class12Id = 'class-12-sci';
  const class11Id = 'class-11-sci';
  const class10Id = 'class-10-fnd';

  run(`INSERT INTO classes (id, name, stream, description) VALUES (?, ?, ?, ?)`,
    [class12Id, 'Class 12', 'Science', 'Senior Secondary Board & Competitive Entrance Batch']);
  run(`INSERT INTO classes (id, name, stream, description) VALUES (?, ?, ?, ?)`,
    [class11Id, 'Class 11', 'Science', 'Foundation for JEE / NEET and Board Mastery']);
  run(`INSERT INTO classes (id, name, stream, description) VALUES (?, ?, ?, ?)`,
    [class10Id, 'Class 10', 'Foundation', 'Secondary Board & Olympiad Preparation']);

  // 3. Batches
  const batchPcmId = 'batch-pcm-2027-a';
  const batchPcbId = 'batch-pcb-2027-b';

  run(`INSERT INTO batches (id, name, class_id, academic_session_id, max_capacity) VALUES (?, ?, ?, ?, ?)`,
    [batchPcmId, 'PCM-2027-A', class12Id, sessionId, 40]);
  run(`INSERT INTO batches (id, name, class_id, academic_session_id, max_capacity) VALUES (?, ?, ?, ?, ?)`,
    [batchPcbId, 'PCB-2027-B', class12Id, sessionId, 40]);

  // 4. Subjects
  const subPhyId = 'sub-phy-12';
  const subChmId = 'sub-chm-12';
  const subMthId = 'sub-mth-12';
  const subBioId = 'sub-bio-12';

  run(`INSERT INTO subjects (id, name, code, class_id, description) VALUES (?, ?, ?, ?, ?)`,
    [subPhyId, 'Physics', 'PHY-12', class12Id, 'Mechanics, Electromagnetism, Optics & Modern Physics']);
  run(`INSERT INTO subjects (id, name, code, class_id, description) VALUES (?, ?, ?, ?, ?)`,
    [subChmId, 'Chemistry', 'CHM-12', class12Id, 'Physical, Inorganic, and Organic Chemistry']);
  run(`INSERT INTO subjects (id, name, code, class_id, description) VALUES (?, ?, ?, ?, ?)`,
    [subMthId, 'Mathematics', 'MTH-12', class12Id, 'Calculus, Vectors, Algebra & Coordinate Geometry']);
  run(`INSERT INTO subjects (id, name, code, class_id, description) VALUES (?, ?, ?, ?, ?)`,
    [subBioId, 'Biology', 'BIO-12', class12Id, 'Genetics, Ecology, Physiology & Biotechnology']);

  // 5. Users: Admin, Teachers, Students
  const adminId = 'user-admin-01';
  const teacherPhyId = 'user-teacher-phy';
  const teacherChmId = 'user-teacher-chm';
  const student1Id = 'user-student-01';
  const student2Id = 'user-student-02';

  // Super Admin
  run(
    `INSERT INTO users (id, email, password_hash, role, name, phone)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [adminId, 'admin@beastacademy.edu', hashPassword('Admin@123'), 'admin', 'Dr. Vikram Malhotra', '+91 98765 00001']
  );
  run(
    `INSERT INTO admin_profiles (id, user_id, designation, permissions_json)
     VALUES (?, ?, ?, ?)`,
    ['admin-prof-01', adminId, 'Director of Academics', JSON.stringify({ super_admin: true, all: true })]
  );

  // Physics Teacher
  run(
    `INSERT INTO users (id, email, password_hash, role, name, phone)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [teacherPhyId, 'physics.teacher@beastacademy.edu', hashPassword('Teacher@123'), 'teacher', 'Prof. Rajesh Sharma', '+91 98765 00002']
  );
  run(
    `INSERT INTO teacher_profiles (id, user_id, employee_code, qualification, bio, contact_number)
     VALUES (?, ?, ?, ?, ?, ?)`,
    ['tch-prof-01', teacherPhyId, 'TCH-PHY-01', 'M.Sc., Ph.D. Physics (IIT Delhi)', 'Senior Physics Faculty with 15+ years experience in JEE/NEET prep.', '+91 98765 00002']
  );

  // Chemistry Teacher
  run(
    `INSERT INTO users (id, email, password_hash, role, name, phone)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [teacherChmId, 'chem.teacher@beastacademy.edu', hashPassword('Teacher@123'), 'teacher', 'Dr. Anita Sen', '+91 98765 00003']
  );
  run(
    `INSERT INTO teacher_profiles (id, user_id, employee_code, qualification, bio, contact_number)
     VALUES (?, ?, ?, ?, ?, ?)`,
    ['tch-prof-02', teacherChmId, 'TCH-CHM-02', 'Ph.D. Organic Chemistry', 'Head of Chemistry Department and National Olympiad Mentor.', '+91 98765 00003']
  );

  // Student 1 (Aarav Mehta)
  run(
    `INSERT INTO users (id, email, password_hash, role, name, phone)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [student1Id, 'student1@beastacademy.edu', hashPassword('Student@123'), 'student', 'Aarav Mehta', '+91 98765 11111']
  );
  run(
    `INSERT INTO student_profiles (id, user_id, student_id_number, class_id, batch_id, academic_session_id, emergency_contact)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ['stu-prof-01', student1Id, 'STU-2026-001', class12Id, batchPcmId, sessionId, '+91 98765 99991']
  );

  // Student 2 (Diya Patel)
  run(
    `INSERT INTO users (id, email, password_hash, role, name, phone)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [student2Id, 'student2@beastacademy.edu', hashPassword('Student@123'), 'student', 'Diya Patel', '+91 98765 22222']
  );
  run(
    `INSERT INTO student_profiles (id, user_id, student_id_number, class_id, batch_id, academic_session_id, emergency_contact)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ['stu-prof-02', student2Id, 'STU-2026-002', class12Id, batchPcmId, sessionId, '+91 98765 99992']
  );

  // 6. Enrollments
  run(`INSERT INTO enrollments (id, student_id, batch_id, academic_session_id, status) VALUES (?, ?, ?, ?, ?)`,
    ['enr-01', student1Id, batchPcmId, sessionId, 'active']);
  run(`INSERT INTO enrollments (id, student_id, batch_id, academic_session_id, status) VALUES (?, ?, ?, ?, ?)`,
    ['enr-02', student2Id, batchPcmId, sessionId, 'active']);

  // 7. Teacher Assignments
  run(`INSERT INTO teacher_assignments (id, teacher_id, batch_id, subject_id, academic_session_id) VALUES (?, ?, ?, ?, ?)`,
    ['ta-01', teacherPhyId, batchPcmId, subPhyId, sessionId]);
  run(`INSERT INTO teacher_assignments (id, teacher_id, batch_id, subject_id, academic_session_id) VALUES (?, ?, ?, ?, ?)`,
    ['ta-02', teacherChmId, batchPcmId, subChmId, sessionId]);

  // 8. Timetable (Monday to Friday)
  // Day 1: Monday, Day 2: Tuesday, Day 3: Wednesday, Day 4: Thursday, Day 5: Friday, Day 6: Saturday
  const days = [1, 2, 3, 4, 5, 6];
  days.forEach((day) => {
    // 08:30 - 10:00: Physics
    run(
      `INSERT OR IGNORE INTO timetables (id, batch_id, subject_id, teacher_id, day_of_week, start_time, end_time, room_number)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [`tt-phy-${day}`, batchPcmId, subPhyId, teacherPhyId, day, '08:30', '10:00', 'Lecture Hall Alpha']
    );
    // 10:15 - 11:45: Chemistry
    run(
      `INSERT OR IGNORE INTO timetables (id, batch_id, subject_id, teacher_id, day_of_week, start_time, end_time, room_number)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [`tt-chm-${day}`, batchPcmId, subChmId, teacherChmId, day, '10:15', '11:45', 'Lab Block Beta']
    );
  });

  // 9. Attendance records (for recent days)
  const todayStr = new Date().toISOString().split('T')[0];
  run(
    `INSERT OR IGNORE INTO attendance (id, batch_id, subject_id, student_id, date, status, marked_by, remarks)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ['att-01', batchPcmId, subPhyId, student1Id, todayStr, 'present', teacherPhyId, 'Attentive in class']
  );
  run(
    `INSERT OR IGNORE INTO attendance (id, batch_id, subject_id, student_id, date, status, marked_by, remarks)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ['att-02', batchPcmId, subPhyId, student2Id, todayStr, 'late', teacherPhyId, 'Arrived 10 mins late']
  );

  // 10. Notices
  run(
    `INSERT INTO notices (id, title, description, category, priority, target_type, target_id, author_id, publish_date, is_pinned)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
    [
      'notice-01',
      'Phase 1 JEE Advanced Diagnostic Mock Test Series',
      'The first institutional mock test series will commence next Monday. Hall tickets and seating plans have been published on the student portal.',
      'exam',
      'urgent',
      'all',
      null,
      adminId,
      todayStr
    ]
  );
  run(
    `INSERT INTO notices (id, title, description, category, priority, target_type, target_id, author_id, publish_date, is_pinned)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`,
    [
      'notice-02',
      'Electromagnetism Problem Sets Available',
      'Chapter 4 Advanced Problem Set with step-by-step analytical solutions is now available under Study Materials.',
      'academic',
      'high',
      'batch',
      batchPcmId,
      teacherPhyId,
      todayStr
    ]
  );

  // 11. Assignments
  const tomorrowStr = new Date(Date.now() + 86400000 * 2).toISOString().split('T')[0];
  const assign1Id = 'assign-phy-01';
  run(
    `INSERT INTO assignments (id, title, subject_id, batch_id, teacher_id, description, deadline, max_marks, instructions)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      assign1Id,
      'Rotational Dynamics & Torque Practice Problems',
      subPhyId,
      batchPcmId,
      teacherPhyId,
      'Solve exercises 1 through 15 from Chapter 7. Show full free-body diagrams and torque equilibrium conditions.',
      `${tomorrowStr} 23:59`,
      50,
      'Submit as a clear single PDF or high-resolution images. Neat handwriting is required.'
    ]
  );

  // Submission by Student 1
  run(
    `INSERT INTO assignment_submissions (id, assignment_id, student_id, file_url, notes, submitted_at, status, marks, feedback, reviewed_by, reviewed_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      'sub-01',
      assign1Id,
      student1Id,
      '/uploads/submissions/aarav_rotational_dynamics.pdf',
      'Completed all 15 questions with free-body diagrams.',
      todayStr,
      'reviewed',
      48,
      'Outstanding work on the angular momentum conservation problem. Step 12 was exceptionally clear.',
      teacherPhyId,
      todayStr
    ]
  );

  // 12. Study Materials
  run(
    `INSERT INTO study_materials (id, title, description, file_url, file_type, file_size, subject_id, batch_id, class_id, chapter, teacher_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      'mat-phy-01',
      'Key Formulas & Theorems: Rotational Dynamics',
      'Comprehensive formula sheet including parallel axis theorem, radius of gyration, and rolling without slipping conditions.',
      '/uploads/materials/rotational_dynamics_formulas.pdf',
      'application/pdf',
      1420500,
      subPhyId,
      batchPcmId,
      class12Id,
      'Chapter 7: System of Particles and Rotational Motion',
      teacherPhyId
    ]
  );
  run(
    `INSERT INTO study_materials (id, title, description, file_url, file_type, file_size, subject_id, batch_id, class_id, chapter, teacher_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      'mat-chm-01',
      'Reaction Mechanisms: Aldehydes, Ketones and Carboxylic Acids',
      'Curated nucleophilic addition reaction pathways and synthesis roadmaps.',
      '/uploads/materials/organic_mechanisms_vol1.pdf',
      'application/pdf',
      2180000,
      subChmId,
      batchPcmId,
      class12Id,
      'Chapter 12: Aldehydes and Ketones',
      teacherChmId
    ]
  );

  // 13. Exams & Results
  const examId = 'exam-midterm-2026';
  run(
    `INSERT INTO exams (id, title, academic_session_id, batch_id, exam_type, start_date, end_date, instructions)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      examId,
      'Mid-Term Assessment 2026',
      sessionId,
      batchPcmId,
      'mid_term',
      '2026-10-15',
      '2026-10-22',
      'Standard pen-and-paper examination. Bring scientific calculators where permitted.'
    ]
  );

  const examSubPhyId = 'exam-sub-phy-01';
  run(
    `INSERT INTO exam_subjects (id, exam_id, subject_id, exam_date, start_time, duration_minutes, max_marks, passing_marks)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [examSubPhyId, examId, subPhyId, '2026-10-15', '09:00', 180, 100, 40]
  );

  run(
    `INSERT INTO results (id, exam_subject_id, student_id, marks_obtained, max_marks, percentage, grade, feedback, entered_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      'res-01',
      examSubPhyId,
      student1Id,
      94,
      100,
      94.0,
      'A+',
      'Demonstrated master-level conceptual clarity in mechanics and wave optics.',
      teacherPhyId
    ]
  );
  run(
    `INSERT INTO results (id, exam_subject_id, student_id, marks_obtained, max_marks, percentage, grade, feedback, entered_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      'res-02',
      examSubPhyId,
      student2Id,
      82,
      100,
      82.0,
      'A',
      'Good conceptual grasp. Review rotational inertia questions for improved precision.',
      teacherPhyId
    ]
  );

  // 14. Fee Records
  run(
    `INSERT INTO fee_records (id, student_id, academic_session_id, fee_title, amount, due_date, status, paid_amount, payment_date, receipt_reference, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      'fee-01',
      student1Id,
      sessionId,
      'Academic Term 1 Tuition Fee',
      25000.0,
      '2026-05-15',
      'paid',
      25000.0,
      '2026-05-10',
      'REC-2026-00481',
      'Full term fee received via bank transfer'
    ]
  );
  run(
    `INSERT INTO fee_records (id, student_id, academic_session_id, fee_title, amount, due_date, status, paid_amount, payment_date, receipt_reference, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      'fee-02',
      student2Id,
      sessionId,
      'Academic Term 1 Tuition Fee',
      25000.0,
      '2026-05-15',
      'pending',
      0.0,
      null,
      null,
      'Invoice generated and dispatched'
    ]
  );

  // 15. Doubts (DoubtDeck Core System)
  const doubt1Id = 'doubt-01';
  run(
    `INSERT INTO doubts (id, student_id, subject_id, batch_id, title, topic, note, status, priority)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      doubt1Id,
      student1Id,
      subPhyId,
      batchPcmId,
      'Confusion regarding pure rolling condition on an inclined plane',
      'Rolling Motion',
      'Why does static friction not dissipate mechanical energy during pure rolling down an inclined plane if it exerts a net torque?',
      'answered',
      'high'
    ]
  );

  // Teacher response to Doubt 1
  run(
    `INSERT INTO doubt_responses (id, doubt_id, author_id, role, message)
     VALUES (?, ?, ?, ?, ?)`,
    [
      'dr-01',
      doubt1Id,
      teacherPhyId,
      'teacher',
      'Excellent question, Aarav! In pure rolling, the instantaneous point of contact between the rolling body and the inclined plane is at rest relative to the surface (velocity = 0). Since instantaneous displacement at the contact point is zero, the work done by static friction is zero (dW = F · ds = 0). Hence, no mechanical energy is converted to heat!'
    ]
  );

  // 16. Actionable Notifications
  run(
    `INSERT INTO notifications (id, user_id, title, message, type, reference_id, is_read)
     VALUES (?, ?, ?, ?, ?, ?, 0)`,
    [
      'notif-01',
      student1Id,
      'Teacher Answered Your Doubt',
      'Prof. Rajesh Sharma answered your doubt on "Rolling Motion".',
      'doubt',
      doubt1Id
    ]
  );
  run(
    `INSERT INTO notifications (id, user_id, title, message, type, reference_id, is_read)
     VALUES (?, ?, ?, ?, ?, ?, 0)`,
    [
      'notif-02',
      student1Id,
      'Physics Assignment Due Soon',
      'Rotational Dynamics & Torque Practice Problems is due tomorrow at 23:59.',
      'assignment',
      assign1Id
    ]
  );

  // 17. Audit Log
  run(
    `INSERT INTO audit_logs (id, user_id, action, entity_type, entity_id, details_json, ip_address)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      'audit-01',
      adminId,
      'SYSTEM_INIT_AND_SEED',
      'system',
      'beast-academy',
      JSON.stringify({ message: 'Academic session, users, classes, batches and curriculum successfully initialized.' }),
      '127.0.0.1'
    ]
  );

  console.log('[SEED] Successfully seeded B.E.A.S.T ACADEMY database!');
  console.log('----------------------------------------------------');
  console.log('Default Credentials:');
  console.log('Super Admin: admin@beastacademy.edu / Admin@123');
  console.log('Teacher:     physics.teacher@beastacademy.edu / Teacher@123');
  console.log('Student:     student1@beastacademy.edu / Student@123');
  console.log('----------------------------------------------------');
}

if (require.main === module) {
  seedDatabase();
}

module.exports = { seedDatabase };
