import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Default production HTTPS URL for release builds (can be overridden via --dart-define=API_BASE_URL=https://...)
  static const String _defaultProductionUrl = 'https://api.beastacademy.edu';

  static String get baseUrl {
    // 1. Explicit override via --dart-define=API_BASE_URL=...
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    // 2. Release builds for Web and Mobile across the Internet use HTTPS production backend
    if (kReleaseMode) {
      return _defaultProductionUrl;
    }

    // 3. Local development mode
    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    // 4. Android emulator development loopback (or adb reverse tcp:5000 tcp:5000 for local USB test)
    return 'http://10.0.2.2:5000';
  }

  // Endpoints
  static const String login = '/api/auth/login';
  static const String authGoogle = '/api/auth/google';
  static const String activateStudent = '/api/auth/activate/student';
  static const String sendOtp = '/api/auth/activate/send-otp';
  static const String verifyOtp = '/api/auth/activate/verify';
  static const String me = '/api/auth/me';
  static const String changePassword = '/api/auth/change-password';
  static const String recoverRequest = '/api/auth/recover-request';
  static const String logout = '/api/auth/logout';

  static const String studentDashboard = '/api/dashboard/student';
  static const String teacherDashboard = '/api/dashboard/teacher';
  static const String adminDashboard = '/api/dashboard/admin';

  static const String timetableMy = '/api/timetable/my';
  static const String timetable = '/api/timetable';

  static const String attendanceBatch = '/api/attendance/batch';
  static const String attendanceMy = '/api/attendance/my';
  static const String attendanceSummary = '/api/attendance/summary';

  static const String assignmentsMy = '/api/assignments/my';
  static const String assignments = '/api/assignments';

  static const String materials = '/api/materials';
  static const String notices = '/api/notices';

  static const String exams = '/api/exams';
  static const String resultsMy = '/api/results/my';
  static const String resultsBatch = '/api/results/batch';

  static const String feesMy = '/api/fees/my';
  static const String fees = '/api/fees';

  static const String doubtsMy = '/api/doubts/my';
  static const String doubtsAssigned = '/api/doubts/assigned';
  static const String doubts = '/api/doubts';

  static const String notificationsMy = '/api/notifications/my';
  static const String search = '/api/search';
  static const String auditLogs = '/api/audit-logs';
  static const String aiStatus = '/api/ai/status';

  static const String academicsSessions = '/api/academics/sessions';
  static const String academicsClasses = '/api/academics/classes';
  static const String academicsBatches = '/api/academics/batches';
  static const String academicsSubjects = '/api/academics/subjects';
  static const String academicsStudents = '/api/academics/students';
  static const String academicsTeachers = '/api/academics/teachers';
  static const String academicsTeacherAssignments = '/api/academics/teacher-assignments';
  static const String admins = '/api/admins';
}
