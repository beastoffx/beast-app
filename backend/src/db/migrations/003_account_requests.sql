-- Migration 003: Add account_requests table for multi-tier institutional onboarding approval
CREATE TABLE IF NOT EXISTS account_requests (
    id VARCHAR(64) PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(32),
    google_uid VARCHAR(128),
    requested_role VARCHAR(32) NOT NULL CHECK (requested_role IN ('student', 'teacher', 'admin')),
    status VARCHAR(32) NOT NULL CHECK (status IN (
        'PENDING_TEACHER_REVIEW',
        'PENDING_ADMIN_REVIEW',
        'PENDING_SUPER_ADMIN_REVIEW',
        'APPROVED',
        'REJECTED'
    )),
    target_class_id VARCHAR(64) REFERENCES classes(id) ON DELETE SET NULL,
    target_batch_id VARCHAR(64) REFERENCES batches(id) ON DELETE SET NULL,
    target_session_id VARCHAR(64) REFERENCES academic_sessions(id) ON DELETE SET NULL,
    qualification TEXT,
    department TEXT,
    notes TEXT,
    teacher_reviewer_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    teacher_reviewed_at TIMESTAMPTZ,
    teacher_review_notes TEXT,
    admin_reviewer_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    admin_reviewed_at TIMESTAMPTZ,
    admin_review_notes TEXT,
    super_admin_reviewer_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    super_admin_reviewed_at TIMESTAMPTZ,
    super_admin_review_notes TEXT,
    rejection_reason TEXT,
    generated_student_id VARCHAR(64),
    created_user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_account_requests_email ON account_requests(email);
CREATE INDEX IF NOT EXISTS idx_account_requests_google_uid ON account_requests(google_uid);
CREATE INDEX IF NOT EXISTS idx_account_requests_status ON account_requests(status);
CREATE INDEX IF NOT EXISTS idx_account_requests_role ON account_requests(requested_role);
