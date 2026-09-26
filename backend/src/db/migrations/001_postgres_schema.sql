-- ==============================================================================
-- B.E.A.S.T ACADEMY Central PostgreSQL Schema (Supabase Migration 001)
-- Production-grade schema supporting PostgreSQL 14+ / Supabase
-- ==============================================================================

-- 1. Users
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    google_uid VARCHAR(128) UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    role VARCHAR(32) NOT NULL CHECK (role IN ('student', 'teacher', 'admin', 'super_admin', 'parent', 'staff')),
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(32),
    phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(32) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending_activation', 'suspended', 'archived', 'expired')),
    avatar_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_google_uid ON users(google_uid);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- 2. Academic Sessions
CREATE TABLE IF NOT EXISTS academic_sessions (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_current BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Classes
CREATE TABLE IF NOT EXISTS classes (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    stream VARCHAR(64),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Batches
CREATE TABLE IF NOT EXISTS batches (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    class_id VARCHAR(64) NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    academic_session_id VARCHAR(64) NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    max_capacity INTEGER NOT NULL DEFAULT 40,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(name, academic_session_id)
);

CREATE INDEX IF NOT EXISTS idx_batches_class ON batches(class_id);
CREATE INDEX IF NOT EXISTS idx_batches_session ON batches(academic_session_id);

-- 5. Subjects
CREATE TABLE IF NOT EXISTS subjects (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    code VARCHAR(32) NOT NULL,
    class_id VARCHAR(64) NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(code, class_id)
);

CREATE INDEX IF NOT EXISTS idx_subjects_class ON subjects(class_id);

-- 6. Student Profiles
CREATE TABLE IF NOT EXISTS student_profiles (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    student_id_number VARCHAR(64) UNIQUE NOT NULL,
    class_id VARCHAR(64) REFERENCES classes(id) ON DELETE SET NULL,
    batch_id VARCHAR(64) REFERENCES batches(id) ON DELETE SET NULL,
    academic_session_id VARCHAR(64) REFERENCES academic_sessions(id) ON DELETE SET NULL,
    subscription_status VARCHAR(32) NOT NULL DEFAULT 'paid' CHECK (subscription_status IN ('paid', 'free', 'expired', 'suspended')),
    access_start_date TIMESTAMPTZ,
    access_end_date TIMESTAMPTZ,
    resource_permissions_json JSONB DEFAULT '{"materials": true, "doubts": true, "exams": true}'::jsonb,
    emergency_contact VARCHAR(64),
    enrollment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_student_profiles_user ON student_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_student_profiles_batch ON student_profiles(batch_id);
CREATE INDEX IF NOT EXISTS idx_student_profiles_id_num ON student_profiles(student_id_number);
CREATE INDEX IF NOT EXISTS idx_student_profiles_subscription ON student_profiles(subscription_status);

-- 7. Teacher Profiles
CREATE TABLE IF NOT EXISTS teacher_profiles (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    employee_code VARCHAR(64) UNIQUE NOT NULL,
    qualification VARCHAR(255),
    bio TEXT,
    contact_number VARCHAR(32),
    joining_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_teacher_profiles_user ON teacher_profiles(user_id);

-- 8. Admin Profiles
CREATE TABLE IF NOT EXISTS admin_profiles (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    admin_id_number VARCHAR(64) UNIQUE,
    designation VARCHAR(128) NOT NULL DEFAULT 'Administrator',
    permissions_json JSONB DEFAULT '{"all": true}'::jsonb,
    created_by VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_profiles_admin_id ON admin_profiles(admin_id_number);

-- 9. Enrollments (Student - Batch - Session)
CREATE TABLE IF NOT EXISTS enrollments (
    id VARCHAR(64) PRIMARY KEY,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    batch_id VARCHAR(64) NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    academic_session_id VARCHAR(64) NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'transferred', 'dropped')),
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, batch_id, academic_session_id)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_student ON enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_batch ON enrollments(batch_id);

-- 10. Teacher Assignments (Teacher - Batch - Subject)
CREATE TABLE IF NOT EXISTS teacher_assignments (
    id VARCHAR(64) PRIMARY KEY,
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    batch_id VARCHAR(64) NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    academic_session_id VARCHAR(64) NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(teacher_id, batch_id, subject_id, academic_session_id)
);

CREATE INDEX IF NOT EXISTS idx_teacher_assignments_teacher ON teacher_assignments(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_assignments_batch ON teacher_assignments(batch_id);

-- 11. Timetables (Schedule slots with double-booking prevention)
CREATE TABLE IF NOT EXISTS timetables (
    id VARCHAR(64) PRIMARY KEY,
    batch_id VARCHAR(64) NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_time VARCHAR(8) NOT NULL,
    end_time VARCHAR(8) NOT NULL,
    room_number VARCHAR(64) NOT NULL DEFAULT 'Hall 1',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(batch_id, day_of_week, start_time),
    UNIQUE(teacher_id, day_of_week, start_time)
);

CREATE INDEX IF NOT EXISTS idx_timetables_batch ON timetables(batch_id);
CREATE INDEX IF NOT EXISTS idx_timetables_teacher ON timetables(teacher_id);
CREATE INDEX IF NOT EXISTS idx_timetables_day ON timetables(day_of_week);

-- 12. Attendance
CREATE TABLE IF NOT EXISTS attendance (
    id VARCHAR(64) PRIMARY KEY,
    batch_id VARCHAR(64) NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status VARCHAR(16) NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
    marked_by VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(batch_id, subject_id, student_id, date)
);

CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_batch_date ON attendance(batch_id, date);
CREATE INDEX IF NOT EXISTS idx_attendance_subject ON attendance(subject_id);

-- 13. Notices
CREATE TABLE IF NOT EXISTS notices (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(32) NOT NULL CHECK (category IN ('academic', 'exam', 'class', 'holiday', 'general', 'urgent')),
    priority VARCHAR(16) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    attachment_url TEXT,
    target_type VARCHAR(16) NOT NULL DEFAULT 'all' CHECK (target_type IN ('all', 'batch', 'class', 'role')),
    target_id VARCHAR(64),
    author_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    publish_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expiry_date TIMESTAMPTZ,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notices_target ON notices(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_notices_priority ON notices(priority);

-- 14. Assignments
CREATE TABLE IF NOT EXISTS assignments (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    batch_id VARCHAR(64) NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    deadline TIMESTAMPTZ NOT NULL,
    max_marks INTEGER NOT NULL DEFAULT 100,
    attachment_url TEXT,
    instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assignments_batch ON assignments(batch_id);
CREATE INDEX IF NOT EXISTS idx_assignments_teacher ON assignments(teacher_id);
CREATE INDEX IF NOT EXISTS idx_assignments_deadline ON assignments(deadline);

-- 15. Assignment Submissions
CREATE TABLE IF NOT EXISTS assignment_submissions (
    id VARCHAR(64) PRIMARY KEY,
    assignment_id VARCHAR(64) NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    file_url TEXT,
    notes TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(16) NOT NULL DEFAULT 'submitted' CHECK (status IN ('pending', 'submitted', 'late', 'reviewed')),
    marks INTEGER,
    feedback TEXT,
    reviewed_by VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    UNIQUE(assignment_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_submissions_assignment ON assignment_submissions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_submissions_student ON assignment_submissions(student_id);

-- 16. Study Materials
CREATE TABLE IF NOT EXISTS study_materials (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    file_url TEXT NOT NULL,
    file_type VARCHAR(64) NOT NULL,
    file_size BIGINT NOT NULL DEFAULT 0,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    batch_id VARCHAR(64) REFERENCES batches(id) ON DELETE SET NULL,
    class_id VARCHAR(64) NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    chapter VARCHAR(128),
    teacher_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_materials_subject ON study_materials(subject_id);
CREATE INDEX IF NOT EXISTS idx_materials_class ON study_materials(class_id);
CREATE INDEX IF NOT EXISTS idx_materials_batch ON study_materials(batch_id);

-- 17. Exams
CREATE TABLE IF NOT EXISTS exams (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    academic_session_id VARCHAR(64) NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    batch_id VARCHAR(64) REFERENCES batches(id) ON DELETE CASCADE,
    exam_type VARCHAR(32) NOT NULL DEFAULT 'offline' CHECK (exam_type IN ('offline', 'unit_test', 'mid_term', 'final', 'mock')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exams_batch ON exams(batch_id);
CREATE INDEX IF NOT EXISTS idx_exams_session ON exams(academic_session_id);

-- 18. Exam Subjects
CREATE TABLE IF NOT EXISTS exam_subjects (
    id VARCHAR(64) PRIMARY KEY,
    exam_id VARCHAR(64) NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    exam_date DATE NOT NULL,
    start_time VARCHAR(8) NOT NULL,
    duration_minutes INTEGER NOT NULL DEFAULT 180,
    max_marks NUMERIC(6,2) NOT NULL DEFAULT 100,
    passing_marks NUMERIC(6,2) NOT NULL DEFAULT 35,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(exam_id, subject_id)
);

CREATE INDEX IF NOT EXISTS idx_exam_subjects_exam ON exam_subjects(exam_id);

-- 19. Results
CREATE TABLE IF NOT EXISTS results (
    id VARCHAR(64) PRIMARY KEY,
    exam_subject_id VARCHAR(64) NOT NULL REFERENCES exam_subjects(id) ON DELETE CASCADE,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    marks_obtained NUMERIC(6,2) NOT NULL,
    max_marks NUMERIC(6,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) NOT NULL,
    grade VARCHAR(8),
    feedback TEXT,
    entered_by VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(exam_subject_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_results_student ON results(student_id);
CREATE INDEX IF NOT EXISTS idx_results_exam_subject ON results(exam_subject_id);

-- 20. Fee Records
CREATE TABLE IF NOT EXISTS fee_records (
    id VARCHAR(64) PRIMARY KEY,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    academic_session_id VARCHAR(64) NOT NULL REFERENCES academic_sessions(id) ON DELETE CASCADE,
    fee_title VARCHAR(255) NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    due_date DATE NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'pending' CHECK (status IN ('paid', 'pending', 'partial', 'overdue')),
    paid_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    payment_date DATE,
    receipt_reference VARCHAR(128),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fee_records_student ON fee_records(student_id);
CREATE INDEX IF NOT EXISTS idx_fee_records_status ON fee_records(status);

-- 21. Doubts (DoubtDeck)
CREATE TABLE IF NOT EXISTS doubts (
    id VARCHAR(64) PRIMARY KEY,
    student_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject_id VARCHAR(64) NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    batch_id VARCHAR(64) REFERENCES batches(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    topic VARCHAR(128),
    note TEXT NOT NULL,
    image_url TEXT,
    status VARCHAR(32) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'seen', 'in_discussion', 'answered', 'resolved')),
    priority VARCHAR(16) NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_doubts_student ON doubts(student_id);
CREATE INDEX IF NOT EXISTS idx_doubts_subject ON doubts(subject_id);
CREATE INDEX IF NOT EXISTS idx_doubts_status ON doubts(status);

-- 22. Doubt Responses
CREATE TABLE IF NOT EXISTS doubt_responses (
    id VARCHAR(64) PRIMARY KEY,
    doubt_id VARCHAR(64) NOT NULL REFERENCES doubts(id) ON DELETE CASCADE,
    author_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(16) NOT NULL CHECK (role IN ('teacher', 'student', 'admin')),
    message TEXT NOT NULL,
    attachment_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_doubt_responses_doubt ON doubt_responses(doubt_id);

-- 23. Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(32) NOT NULL CHECK (type IN ('class', 'assignment', 'material', 'notice', 'exam', 'result', 'doubt', 'attendance', 'fee', 'system')),
    reference_id VARCHAR(64),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read);

-- 24. Audit Logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id VARCHAR(64) PRIMARY KEY,
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(128) NOT NULL,
    entity_type VARCHAR(64) NOT NULL,
    entity_id VARCHAR(64),
    details_json JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

-- 25. Phone Verifications (OTP Lifecycle)
CREATE TABLE IF NOT EXISTS phone_verifications (
    id VARCHAR(64) PRIMARY KEY,
    phone VARCHAR(32) NOT NULL,
    otp_hash VARCHAR(255) NOT NULL,
    session_id VARCHAR(128) UNIQUE NOT NULL,
    student_id_number VARCHAR(64) NOT NULL,
    google_uid VARCHAR(128) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phone_verifications_session ON phone_verifications(session_id);
CREATE INDEX IF NOT EXISTS idx_phone_verifications_phone ON phone_verifications(phone);

-- 26. Email Verifications (OTP Lifecycle)
CREATE TABLE IF NOT EXISTS email_verifications (
    id VARCHAR(64) PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    otp_hash VARCHAR(255) NOT NULL,
    session_id VARCHAR(128) UNIQUE NOT NULL,
    student_id_number VARCHAR(64) NOT NULL,
    google_uid VARCHAR(128) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_verifications_session ON email_verifications(session_id);
CREATE INDEX IF NOT EXISTS idx_email_verifications_email ON email_verifications(email);
