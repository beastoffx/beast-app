-- Migration 002: Add email_verifications table for Email OTP authentication
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
