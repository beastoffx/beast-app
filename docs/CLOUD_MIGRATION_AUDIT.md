# B.E.A.S.T ACADEMY — Cloud Migration & Architecture Audit
**Document Version:** 1.0.0  
**Date:** 2026-09-26  
**Status:** COMPLETE (Zero secrets exposed)  
**Target Architecture:** Flutter (Android/Web) ➔ Node.js API ➔ Supabase PostgreSQL & Storage + Google OAuth Verification

---

## 1. Current Flutter Architecture
- **Framework & SDK:** Flutter 3.47.5 (Channel stable), Dart 3.13.4.
- **State Management:** MVVM architecture utilizing the `Provider` package (`provider: ^6.1.2`).
  - `AuthProvider`: Session management, JWT storage, user/profile reactive state.
  - `StudentProvider`: Timetable, attendance stats, assignments, materials, doubt capture, fee ledger.
  - `TeacherProvider`: Class schedules, 3-tap attendance marking, assignment review & grading, doubt resolver.
  - `AdminProvider`: Institutional dashboard metrics, batch & class management, timetable collision checks, fee records, audit logs.
- **Responsive Layout:** `ResponsiveLayout` widget dynamically toggles between a bottom navigation bar for mobile (< 768px) and a desktop navigation rail / sidebar (>= 768px).
- **Design System:** Academy Theme:
  - Deep Navy: `#0B192C`
  - Slate Surfaces: `#1E3E62`
  - Warm Amber: `#F19E38`
  - Emerald Success: `#10B981`
  - Typography: Google Fonts (Outfit & Inter)
- **Client Services:** `ApiService` abstracts HTTP communication (`http: ^1.2.0`), automatically injects Bearer JWT tokens, manages local caching via `SharedPreferences`, and standardizes error responses.

---

## 2. Current Node.js Backend Architecture
- **Runtime & Engine:** Node.js v24.11.1 with built-in `node:sqlite` database engine.
- **Framework:** Express 4.21.2 structured in a modular controller-route architecture.
- **Application Factory:** `createApp()` pattern in `backend/src/server.js` enabling clean test isolation and concurrent server instances.
- **Active Middleware Pipeline:**
  - `helmet`: Security headers including cross-origin resource policy.
  - `cors`: Cross-Origin Resource Sharing for mobile and web clients.
  - `morgan`: HTTP request logging in non-test environments.
  - `express.json` & `express.urlencoded`: 10 MB payload parsing limits.
  - `authenticateToken`: Real-time session verification.
  - `authorizeRoles`: Role-based route protection.
  - `logAudit`: Tamper-evident logging of critical actions.
  - `errorHandler` & `notFoundHandler`: Standardized JSON envelopes.

---

## 3. Current Authentication Implementation
- **Mechanism:** Email & password authentication with salted bcrypt hashes (10 salt rounds).
- **Controller/Router:** `backend/src/routes/authRoutes.js`.
- **Endpoints:**
  - `POST /api/auth/login`: Validates credentials, checks account status, returns JWT and user profile.
  - `GET /api/auth/me`: Authenticated endpoint returning current user identity and profile.
  - `POST /api/auth/change-password`: Authenticated password updates with length validation.
  - `POST /api/auth/recover-request`: Rate-limited recovery request with uniform responses to prevent user enumeration.
  - `POST /api/auth/logout`: Records logout audit log and invalidates client session.

---

## 4. Current JWT & Session Implementation
- **Library:** `jsonwebtoken: ^9.0.2`.
- **Payload Structure:** `{ id, email, role, name }`.
- **Token Format:** Bearer token transmitted in HTTP `Authorization` header.
- **Lifetime:** Configurable via `JWT_EXPIRES_IN` (default: `7d`).
- **Live Verification:** On every request, `authenticateToken` queries `users` table to verify user existence and check `is_active = 1`. Deactivated users are instantly rejected with HTTP 403 Forbidden.

---

## 5. Current RBAC Implementation
- **Roles:** `student`, `teacher`, `admin`, `parent`, `staff`.
- **Database Enforcement:** `CHECK (role IN ('student', 'teacher', 'admin', 'parent', 'staff'))`.
- **Middleware:** `authorizeRoles(...allowedRoles)` in `backend/src/middleware/rbac.js`.
- **Boundary Protections:**
  - Students cannot access administrative dashboards, create timetable slots, or mark attendance.
  - Teachers can only view and modify data within their assigned batches and subjects.
  - Students can only view their own grades, attendance records, doubts, and fee ledger.

---

## 6. Current SQLite Schema
- **Database Engine:** `node:sqlite` in WAL (Write-Ahead Logging) mode.
- **Integrity Pragmas:** `PRAGMA foreign_keys = ON;`, `PRAGMA synchronous = NORMAL;`.
- **Schema File:** `backend/src/db/schema.sql` (389 lines of ANSI-compatible SQL DDL).

---

## 7. All 24 Existing Database Tables / Entities
1. `users`: Master identity records with role, password hash, status.
2. `academic_sessions`: Academic school years (e.g. 2026-2027) with active session flag.
3. `classes`: Academic classes (e.g. Class 10, 11, 12) with streams.
4. `batches`: Class divisions (e.g. PCM-2027-A) with capacity limits.
5. `subjects`: Curricular subjects mapped to classes with subject codes.
6. `student_profiles`: Detailed student identity, roll numbers, emergency contacts.
7. `teacher_profiles`: Faculty qualifications, employee codes, bio, joining dates.
8. `admin_profiles`: Administrator designations and structured permission JSON.
9. `enrollments`: Student-to-batch enrollment with status tracking.
10. `teacher_assignments`: Faculty teaching allocations per subject and batch.
11. `timetables`: Weekly schedule with collision prevention constraints.
12. `attendance`: Daily class attendance logs with audit tracking.
13. `notices`: Institutional bulletin board with audience targeting and priority.
14. `assignments`: Teacher-created tasks with deadlines and attachment links.
15. `assignment_submissions`: Student work uploads, status, grades, and teacher feedback.
16. `study_materials`: Chapter-organized academic resources with file metadata.
17. `exams`: Institutional exam schedules (Midterm, Final, Unit Tests).
18. `exam_subjects`: Per-subject datesheet, duration, max/passing marks.
19. `results`: Student exam scores, percentages, grades, and teacher feedback.
20. `fee_records`: Student fee structures, ledger balances, payments, receipt references.
21. `doubts`: Student questions in DoubtDeck with image support and status lifecycle.
22. `doubt_responses`: Multilateral discussion replies between teachers and students.
23. `notifications`: In-app actionable notifications with unread states.
24. `audit_logs`: Tamper-evident logging of administrative and operational actions.

---

## 8. All Existing Relationships & Foreign Keys
- `batches(class_id)` ➔ `classes(id)` [ON DELETE CASCADE]
- `batches(academic_session_id)` ➔ `academic_sessions(id)` [ON DELETE CASCADE]
- `subjects(class_id)` ➔ `classes(id)` [ON DELETE CASCADE]
- `student_profiles(user_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `teacher_profiles(user_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `admin_profiles(user_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `enrollments(student_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `enrollments(batch_id)` ➔ `batches(id)` [ON DELETE CASCADE]
- `teacher_assignments(teacher_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `teacher_assignments(batch_id)` ➔ `batches(id)` [ON DELETE CASCADE]
- `teacher_assignments(subject_id)` ➔ `subjects(id)` [ON DELETE CASCADE]
- `timetables(batch_id)` ➔ `batches(id)` [ON DELETE CASCADE]
- `timetables(teacher_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `attendance(student_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `attendance(batch_id)` ➔ `batches(id)` [ON DELETE CASCADE]
- `assignments(teacher_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `assignment_submissions(assignment_id)` ➔ `assignments(id)` [ON DELETE CASCADE]
- `assignment_submissions(student_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `study_materials(subject_id)` ➔ `subjects(id)` [ON DELETE CASCADE]
- `exams(batch_id)` ➔ `batches(id)` [ON DELETE CASCADE]
- `exam_subjects(exam_id)` ➔ `exams(id)` [ON DELETE CASCADE]
- `results(exam_subject_id)` ➔ `exam_subjects(id)` [ON DELETE CASCADE]
- `results(student_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `fee_records(student_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `doubts(student_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `doubt_responses(doubt_id)` ➔ `doubts(id)` [ON DELETE CASCADE]
- `notifications(user_id)` ➔ `users(id)` [ON DELETE CASCADE]
- `audit_logs(user_id)` ➔ `users(id)` [ON DELETE SET NULL]

---

## 9. Existing Upload / File Storage Implementation
- **Middleware:** `multer: ^1.4.5-lts.1` configured in `backend/src/middleware/upload.js`.
- **Disk Locations:** `backend/src/uploads/{avatars, doubts, materials, submissions}`.
- **Route:** `app.use('/uploads', express.static(config.uploadDir))`.
- **Validation:** 25 MB max file size; mime-type whitelist (PDF, JPEG, PNG, WEBP, Word, Excel, Plain Text).

---

## 10. Existing API Routes
- `/api/auth`: Login, Profile, Password Changes, Recovery, Logout.
- `/api/academics`: Classes, Batches, Subjects, Enrollments, Teacher Assignments.
- `/api/timetable`: Dynamic schedules, double-booking collision checks.
- `/api/attendance`: Batch attendance logging, subject percentages, audit trails.
- `/api/assignments`: Creation, student submissions, teacher grading & feedback.
- `/api/materials`: Curated chapter resources, upload, download.
- `/api/notices`: Institutional notices, priority filtering, audience targeting.
- `/api/exams`: Examination cycles, datesheets, published status toggle.
- `/api/results`: Student score recording, grade computation, report card delivery.
- `/api/fees`: Fee ledgers, payment recording, overdue status.
- `/api/doubts`: DoubtDeck Q&A lifecycle (Open -> Answered -> Resolved).
- `/api/dashboard`: Role-specific metrics & "Actionable Today" summaries.
- `/api/notifications`: Targeted in-app alerts and read status updates.
- `/api/search`: Scope-filtered global search across materials, notices, and batches.
- `/api/audit-logs`: Administrative action logs.
- `/api/ai`: Section 23 compliant Free-First AI status and policy checks.

---

## 11. Existing Environment Variables
- `PORT`: Server listening port (default: 5000).
- `NODE_ENV`: Runtime environment (`development`, `test`, `production`).
- `JWT_SECRET`: Secret key for JWT signing.
- `JWT_EXPIRES_IN`: Session token validity duration (default: `7d`).
- `DB_PATH`: SQLite database file path.
- `UPLOAD_DIR`: Local filesystem directory for file uploads.

---

## 12. Existing Google OAuth Configuration
- **Application ID:** `com.beastacademy.beast_academy`.
- **Debug SHA-1:** `75:56:B7:5E:EF:E0:E0:86:1A:E3:0B:35:9A:14:B3:14:BD:FB:B9:36`.
- **Debug SHA-256:** `36:36:5B:4A:6E:8B:04:63:86:88:EF:E2:F4:48:09:C0:05:D6:47:AA:E0:51:78:05:76:F6:B9:FB:B8:00:7A:C0`.
- **Status:** Google Cloud Web & Android OAuth Clients configured upstream; discovery complete.

---

## 13. Existing Test Coverage
- **Backend Tests:** 28/28 integration tests passing in `backend/tests/api.test.js`.
- **Frontend Tests:** 6/6 tests passing in `frontend/test/models_and_providers_test.dart` and `frontend/test/widget_test.dart`.

---

## 14. Existing Android Application ID
- `com.beastacademy.beast_academy` (configured in `frontend/android/app/build.gradle.kts`).

---

## 15. Existing Web Configuration
- **PWA Manifest:** `frontend/web/manifest.json`.
- **Entrypoint:** `frontend/web/index.html`.
- **Production Bundle:** Compiled release assets in `frontend/build/web/`.

---

## 16. Existing Development Seed Accounts
- **Super Admin:** `admin@beastacademy.edu` (Password: `Admin@123`)
- **Physics Faculty:** `physics.teacher@beastacademy.edu` (Password: `Teacher@123`)
- **Chemistry Faculty:** `chem.teacher@beastacademy.edu` (Password: `Teacher@123`)
- **Student 1 (Aarav Mehta):** `student1@beastacademy.edu` (Password: `Student@123`, Student ID: `STU-2026-001`)
- **Student 2 (Diya Patel):** `student2@beastacademy.edu` (Password: `Student@123`, Student ID: `STU-2026-002`)
