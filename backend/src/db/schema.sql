-- B.E.A.S.T ACADEMY Relational Database Schema
-- Production-grade schema supporting SQLite and PostgreSQL compatible types

PRAGMA foreign_keys = ON;

-- 1. Users
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    google_uid TEXT UNIQUE,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT, -- Nullable for Google OAuth users, hashed for password users
    role TEXT NOT NULL CHECK (role IN ('student', 'teacher', 'admin', 'super_admin', 'parent', 'staff')),
    name TEXT NOT NULL,
    phone TEXT,
    phone_verified INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending_activation', 'suspended', 'archived', 'expired')),
    avatar_url TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    last_login_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_users_google_uid ON users(google_uid);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- 2. Academic Sessions
CREATE TABLE IF NOT EXISTS academic_sessions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE, -- e.g. "2026-2027"
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    is_current INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 3. Classes
CREATE TABLE IF NOT EXISTS classes (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL, -- e.g. "Class 12"
    stream TEXT, -- e.g. "Science", "Commerce", "Foundation"
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 4. Batches
CREATE TABLE IF NOT EXISTS batches (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL, -- e.g. "PCM-2027-A"
    class_id TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    academic_session_id TEXT NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    max_capacity INTEGER NOT NULL DEFAULT 40,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(name, academic_session_id)
);

CREATE INDEX IF NOT EXISTS idx_batches_class ON batches(class_id);
CREATE INDEX IF NOT EXISTS idx_batches_session ON batches(academic_session_id);

-- 5. Subjects
CREATE TABLE IF NOT EXISTS subjects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL, -- e.g. "Physics"
    code TEXT NOT NULL, -- e.g. "PHY-12"
    class_id TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(code, class_id)
);

CREATE INDEX IF NOT EXISTS idx_subjects_class ON subjects(class_id);

-- 6. Student Profiles
CREATE TABLE IF NOT EXISTS student_profiles (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    student_id_number TEXT UNIQUE NOT NULL, -- e.g. "BST-2027-00001"
    class_id TEXT REFERENCES classes(id) ON DELETE SET NULL,
    batch_id TEXT REFERENCES batches(id) ON DELETE SET NULL,
    academic_session_id TEXT REFERENCES academic_sessions(id) ON DELETE SET NULL,
    subscription_status TEXT NOT NULL DEFAULT 'paid' CHECK (subscription_status IN ('paid', 'free', 'expired', 'suspended')),
    access_start_date TEXT,
    access_end_date TEXT,
    resource_permissions_json TEXT DEFAULT '{"materials": true, "doubts": true, "exams": true}',
    emergency_contact TEXT,
    enrollment_date TEXT NOT NULL DEFAULT (datetime('now')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_student_profiles_user ON student_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_student_profiles_batch ON student_profiles(batch_id);
CREATE INDEX IF NOT EXISTS idx_student_profiles_id_num ON student_profiles(student_id_number);
CREATE INDEX IF NOT EXISTS idx_student_profiles_subscription ON student_profiles(subscription_status);

-- 7. Teacher Profiles
CREATE TABLE IF NOT EXISTS teacher_profiles (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    employee_code TEXT UNIQUE NOT NULL, -- e.g. "TCH-001"
    qualification TEXT,
    bio TEXT,
    contact_number TEXT,
    joining_date TEXT NOT NULL DEFAULT (datetime('now')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_teacher_profiles_user ON teacher_profiles(user_id);

-- 8. Admin Profiles
CREATE TABLE IF NOT EXISTS admin_profiles (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    admin_id_number TEXT UNIQUE, -- e.g. "ADM-2027-00001"
    designation TEXT NOT NULL DEFAULT 'Administrator',
    permissions_json TEXT DEFAULT '{"all": true}',
    created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_admin_profiles_admin_id ON admin_profiles(admin_id_number);

-- 9. Enrollments (Student - Batch - Session)
CREATE TABLE IF NOT EXISTS enrollments (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    batch_id TEXT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    academic_session_id TEXT NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'transferred', 'dropped')),
    enrolled_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(student_id, batch_id, academic_session_id)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_student ON enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_batch ON enrollments(batch_id);

-- 10. Teacher Assignments (Teacher - Batch - Subject)
CREATE TABLE IF NOT EXISTS teacher_assignments (
    id TEXT PRIMARY KEY,
    teacher_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    batch_id TEXT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    academic_session_id TEXT NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    assigned_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(teacher_id, batch_id, subject_id, academic_session_id)
);

CREATE INDEX IF NOT EXISTS idx_teacher_assignments_teacher ON teacher_assignments(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_assignments_batch ON teacher_assignments(batch_id);

-- 11. Timetable (Schedule slots)
CREATE TABLE IF NOT EXISTS timetables (
    id TEXT PRIMARY KEY,
    batch_id TEXT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    teacher_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1: Mon, 7: Sun
    start_time TEXT NOT NULL, -- e.g. "09:00"
    end_time TEXT NOT NULL,   -- e.g. "10:00"
    room_number TEXT NOT NULL DEFAULT 'Hall 1',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    -- Collision prevention constraints:
    UNIQUE(batch_id, day_of_week, start_time),
    UNIQUE(teacher_id, day_of_week, start_time)
);

CREATE INDEX IF NOT EXISTS idx_timetables_batch ON timetables(batch_id);
CREATE INDEX IF NOT EXISTS idx_timetables_teacher ON timetables(teacher_id);
CREATE INDEX IF NOT EXISTS idx_timetables_day ON timetables(day_of_week);

-- 12. Attendance
CREATE TABLE IF NOT EXISTS attendance (
    id TEXT PRIMARY KEY,
    batch_id TEXT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date TEXT NOT NULL, -- YYYY-MM-DD
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
    marked_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    remarks TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(batch_id, subject_id, student_id, date)
);

CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_batch_date ON attendance(batch_id, date);
CREATE INDEX IF NOT EXISTS idx_attendance_subject ON attendance(subject_id);

-- 13. Notices
CREATE TABLE IF NOT EXISTS notices (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('academic', 'exam', 'class', 'holiday', 'general', 'urgent')),
    priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    attachment_url TEXT,
    target_type TEXT NOT NULL DEFAULT 'all' CHECK (target_type IN ('all', 'batch', 'class', 'role')),
    target_id TEXT, -- batch_id or class_id or role name
    author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    publish_date TEXT NOT NULL DEFAULT (datetime('now')),
    expiry_date TEXT,
    is_pinned INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_notices_target ON notices(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_notices_priority ON notices(priority);

-- 14. Assignments
CREATE TABLE IF NOT EXISTS assignments (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    batch_id TEXT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    teacher_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    deadline TEXT NOT NULL,
    max_marks INTEGER NOT NULL DEFAULT 100,
    attachment_url TEXT,
    instructions TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_assignments_batch ON assignments(batch_id);
CREATE INDEX IF NOT EXISTS idx_assignments_teacher ON assignments(teacher_id);
CREATE INDEX IF NOT EXISTS idx_assignments_deadline ON assignments(deadline);

-- 15. Assignment Submissions
CREATE TABLE IF NOT EXISTS assignment_submissions (
    id TEXT PRIMARY KEY,
    assignment_id TEXT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    file_url TEXT,
    notes TEXT,
    submitted_at TEXT NOT NULL DEFAULT (datetime('now')),
    status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('pending', 'submitted', 'late', 'reviewed')),
    marks INTEGER,
    feedback TEXT,
    reviewed_by TEXT REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TEXT,
    UNIQUE(assignment_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_submissions_assignment ON assignment_submissions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_submissions_student ON assignment_submissions(student_id);

-- 16. Study Materials
CREATE TABLE IF NOT EXISTS study_materials (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    file_url TEXT NOT NULL,
    file_type TEXT NOT NULL, -- e.g. "application/pdf", "image/png"
    file_size INTEGER NOT NULL DEFAULT 0, -- in bytes
    subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    batch_id TEXT REFERENCES batches(id) ON DELETE SET NULL,
    class_id TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    chapter TEXT,
    teacher_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_materials_subject ON study_materials(subject_id);
CREATE INDEX IF NOT EXISTS idx_materials_class ON study_materials(class_id);
CREATE INDEX IF NOT EXISTS idx_materials_batch ON study_materials(batch_id);

-- 17. Exams
CREATE TABLE IF NOT EXISTS exams (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL, -- e.g. "Mid-Term Examinations 2026"
    academic_session_id TEXT NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    batch_id TEXT REFERENCES batches(id) ON DELETE CASCADE,
    exam_type TEXT NOT NULL DEFAULT 'offline' CHECK (exam_type IN ('offline', 'unit_test', 'mid_term', 'final', 'mock')),
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    instructions TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_exams_batch ON exams(batch_id);
CREATE INDEX IF NOT EXISTS idx_exams_session ON exams(academic_session_id);

-- 18. Exam Subjects
CREATE TABLE IF NOT EXISTS exam_subjects (
    id TEXT PRIMARY KEY,
    exam_id TEXT NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    exam_date TEXT NOT NULL,
    start_time TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL DEFAULT 180,
    max_marks INTEGER NOT NULL DEFAULT 100,
    passing_marks INTEGER NOT NULL DEFAULT 35,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(exam_id, subject_id)
);

CREATE INDEX IF NOT EXISTS idx_exam_subjects_exam ON exam_subjects(exam_id);

-- 19. Results
CREATE TABLE IF NOT EXISTS results (
    id TEXT PRIMARY KEY,
    exam_subject_id TEXT NOT NULL REFERENCES exam_subjects(id) ON DELETE CASCADE,
    student_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    marks_obtained REAL NOT NULL,
    max_marks REAL NOT NULL DEFAULT 100,
    percentage REAL NOT NULL,
    grade TEXT,
    feedback TEXT,
    entered_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(exam_subject_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_results_student ON results(student_id);
CREATE INDEX IF NOT EXISTS idx_results_exam_subject ON results(exam_subject_id);

-- 20. Fee Records
CREATE TABLE IF NOT EXISTS fee_records (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    academic_session_id TEXT NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    fee_title TEXT NOT NULL, -- e.g. "Term 1 Tuition Fee"
    amount REAL NOT NULL,
    due_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('paid', 'pending', 'partial', 'overdue')),
    paid_amount REAL NOT NULL DEFAULT 0,
    payment_date TEXT,
    receipt_reference TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_fee_records_student ON fee_records(student_id);
CREATE INDEX IF NOT EXISTS idx_fee_records_status ON fee_records(status);

-- 21. Doubts (DoubtDeck Core System)
CREATE TABLE IF NOT EXISTS doubts (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    batch_id TEXT REFERENCES batches(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    topic TEXT,
    note TEXT NOT NULL,
    image_url TEXT,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'seen', 'in_discussion', 'answered', 'resolved')),
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_doubts_student ON doubts(student_id);
CREATE INDEX IF NOT EXISTS idx_doubts_subject ON doubts(subject_id);
CREATE INDEX IF NOT EXISTS idx_doubts_status ON doubts(status);

-- 22. Doubt Responses
CREATE TABLE IF NOT EXISTS doubt_responses (
    id TEXT PRIMARY KEY,
    doubt_id TEXT NOT NULL REFERENCES doubts(id) ON DELETE CASCADE,
    author_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('teacher', 'student', 'admin')),
    message TEXT NOT NULL,
    attachment_url TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_doubt_responses_doubt ON doubt_responses(doubt_id);

-- 23. Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('class', 'assignment', 'material', 'notice', 'exam', 'result', 'doubt', 'attendance', 'fee', 'system')),
    reference_id TEXT,
    is_read INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read);

-- 24. Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT,
    details_json TEXT,
    ip_address TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

-- 25. Phone Verifications (OTP Lifecycle)
CREATE TABLE IF NOT EXISTS phone_verifications (
    id TEXT PRIMARY KEY,
    phone TEXT NOT NULL,
    otp_hash TEXT NOT NULL,
    session_id TEXT UNIQUE NOT NULL,
    student_id_number TEXT NOT NULL,
    google_uid TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    is_verified INTEGER NOT NULL DEFAULT 0,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_phone_verifications_session ON phone_verifications(session_id);
CREATE INDEX IF NOT EXISTS idx_phone_verifications_phone ON phone_verifications(phone);

-- 26. Email Verifications (OTP Lifecycle)
CREATE TABLE IF NOT EXISTS email_verifications (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL,
    otp_hash TEXT NOT NULL,
    session_id TEXT UNIQUE NOT NULL,
    student_id_number TEXT NOT NULL,
    google_uid TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    is_verified INTEGER NOT NULL DEFAULT 0,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_email_verifications_session ON email_verifications(session_id);
CREATE INDEX IF NOT EXISTS idx_email_verifications_email ON email_verifications(email);
