# B.E.A.S.T ACADEMY — Authentication & Identity Architecture
**Document Version:** 1.0.0  
**Date:** 2026-09-26  
**Status:** ARCHITECTED & APPROVED  

---

## 1. Architectural Strategy & Decision Rationale

### The Core Principle
Google Authentication and B.E.A.S.T Authorization operate as two distinct layers:
1. **Google OAuth (Identity Proof):** Verifies that the client controls a specific authenticated Google Account (`google_uid`, verified email, display name).
2. **BEAST Backend (Institutional Authorization):** Authoritatively resolves whether that `google_uid` is linked to an authorized, active, and institution-issued Student, Faculty, or Admin record.

> **Crucial Rule:** Google authentication alone **NEVER** grants Student access. An unlinked Google user cannot access academic schedules, materials, or student records without an authorized institute Student ID and verified phone activation.

### Minimum-Risk Integration: Backend Direct Token Validation vs Supabase Auth Duplication
We evaluated two integration approaches:
- **Option A (Supabase Auth Middleware):** Delegates user session creation to Supabase's proprietary `auth.users` schema.
  - *Drawbacks:* Duplicates user tables, requires complex database synchronization triggers, breaks local SQLite testing without cloud dependencies, and adds unnecessary latency.
- **Option B (Direct Backend Token Verification — Selected):** The Flutter client passes the Google ID token to the BEAST Node.js API (`POST /api/auth/google`). The BEAST backend validates the token signature against Google's public keys via `google-auth-library`, checks the `google_uid` against our central canonical `users` table, and issues the authoritative BEAST Academy JWT.
  - *Benefits:*
    1. Zero architectural duplication: Canonical user identity resides in the core database.
    2. Single authorization pipeline: Preserves all existing RBAC middlewares (`authorizeRoles`), audit logging (`logAudit`), and test suites.
    3. Dual-database compatibility: Works identically in local SQLite testing environments and production Supabase PostgreSQL.
    4. Complete offline resilience & multi-device portability.

---

## 2. Canonical Identity Model

The master `users` table and `student_profiles` table are extended to establish the canonical identity:

```
┌─────────────────────────────────────────────────────────────┐
│                         users Table                         │
├──────────────────────────────┬──────────────────────────────┤
│ id                           │ TEXT / UUID (Primary Key)    │
│ google_uid                   │ TEXT (UNIQUE, Nullable)      │
│ email                        │ TEXT (UNIQUE, NOT NULL)      │
│ password_hash                │ TEXT (Nullable for Google)   │
│ role                         │ TEXT (student, teacher, ...) │
│ name                         │ TEXT NOT NULL                │
│ phone                        │ TEXT (E.164, Nullable)       │
│ phone_verified               │ INTEGER / BOOLEAN (0 or 1)   │
│ status                       │ TEXT (active, suspended, ...)│
│ last_login_at                │ TIMESTAMP                    │
│ created_at, updated_at       │ TIMESTAMP                    │
└──────────────────────────────┴──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    student_profiles Table                   │
├──────────────────────────────┬──────────────────────────────┤
│ id                           │ TEXT / UUID (Primary Key)    │
│ user_id                      │ REFERENCES users(id)         │
│ student_id_number            │ TEXT (UNIQUE, e.g. BST-...)  │
│ class_id, batch_id           │ REFERENCES classes, batches  │
│ subscription_status          │ TEXT (paid, free, expired)   │
│ access_start_date            │ DATE / TIMESTAMP             │
│ access_end_date              │ DATE / TIMESTAMP             │
│ resource_permissions_json    │ JSON / TEXT (Allowed scopes) │
│ emergency_contact            │ TEXT                         │
│ enrollment_date              │ TIMESTAMP                    │
└──────────────────────────────┴──────────────────────────────┘
```

---

## 3. Student First-Time Activation Workflow

```
Student Client                    BEAST Backend                   Google OAuth / OTP
      │                                 │                                 │
      │ 1. Continue with Google         │                                 │
      ├──────────────────────────────────────────────────────────────────►│
      │ 2. Return Google ID Token       │                                 │
      │◄──────────────────────────────────────────────────────────────────┤
      │                                 │                                 │
      │ 3. POST /api/auth/google        │                                 │
      │    { idToken }                  │                                 │
      ├────────────────────────────────►│                                 │
      │                                 │ 4. Verify Google Signature      │
      │                                 ├────────────────────────────────►│
      │                                 │◄────────────────────────────────┤
      │                                 │ 5. Query users(google_uid)      │
      │                                 │    Result: UNLINKED             │
      │ 6. { status: "UNLINKED",        │                                 │
      │      google_uid, email, name }  │                                 │
      │◄────────────────────────────────┤                                 │
      │                                 │                                 │
      │ 7. Show Activation Form         │                                 │
      │    (Student ID + Phone)         │                                 │
      │                                 │                                 │
      │ 8. POST /api/auth/activate/send-otp                               │
      │    { google_uid, student_id, phone }                              │
      ├────────────────────────────────►│                                 │
      │                                 │ 9. Verify Student ID exists     │
      │                                 │    and is eligible              │
      │                                 │ 10. Generate OTP & session      │
      │                                 │ 11. Send SMS OTP                │
      │                                 ├────────────────────────────────►│
      │ 12. { success: true,            │                                 │
      │       session_id }              │                                 │
      │◄────────────────────────────────┤                                 │
      │                                 │                                 │
      │ 13. Student enters OTP          │                                 │
      │                                 │                                 │
      │ 14. POST /api/auth/activate/verify                                │
      │     { session_id, otp, ... }    │                                 │
      ├────────────────────────────────►│                                 │
      │                                 │ 15. Verify OTP                  │
      │                                 │ 16. Atomically Link:            │
      │                                 │     - users.google_uid          │
      │                                 │     - users.phone               │
      │                                 │     - users.phone_verified = 1  │
      │                                 │     - users.status = 'active'   │
      │                                 │ 17. Issue Authoritative JWT     │
      │ 18. { success: true,            │                                 │
      │       token, user, profile }    │                                 │
      │◄────────────────────────────────┤                                 │
      │                                 │                                 │
      │ 19. Enter Student Dashboard     │                                 │
```

---

## 4. Returning Student / Multi-Device Flow

When an already-activated student signs in on any device (new Android phone, tablet, or web browser):
1. Client completes Google Sign-In and receives a valid Google ID Token.
2. Client sends `{ idToken }` to `POST /api/auth/google`.
3. Backend verifies the token and queries `SELECT * FROM users WHERE google_uid = ?`.
4. Match found: Backend immediately loads the authoritative user profile, class, batch, enrollment, and paid subscription status from the central database.
5. Issues a fresh BEAST Academy session token and returns the dashboard payload.
6. Zero local setup required: The student's data is 100% cloud-authoritative and persistent.

---

## 5. Institute-Controlled Student Provisioning (Super Admin)

Super Admins provision students via `POST /api/academics/students`:
- **Collision-Safe Student ID Generation:** Formatted as `BST-<YEAR>-<5-DIGIT-SEQUENCE>` (e.g. `BST-2027-00001`). Enforced with a database `UNIQUE` constraint and atomic sequence generator.
- **Pre-Activation Parameters:** Super Admin configures the student's legal name, class, batch, stream, subscription status (`paid` vs `free`), access start date, and access expiry date.
- **Account State:** Created in `pending_activation` status until the student links their Google account and completes phone verification.

---

## 6. Paid vs Free Access Control

Access control is enforced entirely server-side in API routes:
- **Subscription States:**
  - `active` / `paid`: Unrestricted access to assigned batch materials, assignments, Doubts, and exams.
  - `free`: Core access granted; premium study materials and priority doubt tags require upgraded status.
  - `expired`: Read-only historical access or access-restricted modal prompt.
  - `suspended`: Instant HTTP 403 rejection across all private endpoints.
- Client-side checks like `isPaid = true` are strictly treated as UI hints; the backend verifies subscription validity on every sensitive resource request.

---

## 7. Phone OTP Provider Abstraction (`OtpService`)

To eliminate hardcoded or fake OTPs while maintaining production readiness:
- `BaseOtpProvider` defines the standard contract:
  - `sendOtp(phoneNumber, code)`
  - `verifyOtp(sessionId, code)`
- **Implementations:**
  - `DevConsoleOtpProvider`: For local testing and development; generates cryptographic 6-digit tokens and logs them securely to console without third-party network egress.
  - `TwilioOtpProvider`: Pluggable implementation using Twilio Verify REST API.
  - `Msg91OtpProvider`: Pluggable implementation for Indian SMS gateways.
- Switching between providers requires only updating `OTP_PROVIDER` in environment variables.

---

## 8. Storage Abstraction Layer (`StorageService`)

To protect private student files and support Supabase Storage:
- **Buckets:**
  - `beast-resources`: Study materials, syllabus documents, question banks.
  - `beast-doubts`: Student doubt photos and faculty visual explanations.
- **Private Access:** Buckets are private. Clients never access raw bucket URLs directly.
- **Signed URLs:** The backend generates time-limited signed URLs (TTL 15-60 minutes) only after authenticating the user and verifying their academic enrollment in that subject/batch.
- Local fallback: If `SUPABASE_URL` is omitted, `LocalStorageProvider` automatically manages file storage in `backend/src/uploads/` for offline/development operation.
