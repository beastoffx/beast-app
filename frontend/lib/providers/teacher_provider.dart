import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../models/timetable_model.dart';
import '../models/assignment_model.dart';
import '../models/doubt_model.dart';

class TeacherProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isOffline = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;

  // Teacher Dashboard
  Map<String, dynamic>? _dashboardData;
  List<TimetableSlot> _todayClasses = [];
  TimetableSlot? _nextClass;
  List<dynamic> _assignedBatches = [];
  int _pendingReviewsCount = 0;
  int _pendingDoubtsCount = 0;

  Map<String, dynamic>? get dashboardData => _dashboardData;
  List<TimetableSlot> get todayClasses => _todayClasses;
  TimetableSlot? get nextClass => _nextClass;
  List<dynamic> get assignedBatches => _assignedBatches;
  int get pendingReviewsCount => _pendingReviewsCount;
  int get pendingDoubtsCount => _pendingDoubtsCount;

  // Attendance Sheet
  List<dynamic> _attendanceSheet = [];
  List<dynamic> get attendanceSheet => _attendanceSheet;

  // Assignments & Submissions
  List<AssignmentModel> _assignments = [];
  List<AssignmentSubmissionModel> _submissions = [];
  List<AssignmentModel> get assignments => _assignments;
  List<AssignmentSubmissionModel> get submissions => _submissions;

  // Doubts (DoubtDeck)
  List<DoubtModel> _assignedDoubts = [];
  List<DoubtModel> get assignedDoubts => _assignedDoubts;

  // Fetch Dashboard
  Future<void> fetchDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.get(ApiConstants.teacherDashboard);
    _isLoading = false;
    _isOffline = response.isFromCache;

    if (response.success && response.data != null) {
      _dashboardData = response.data;
      final rawToday = _dashboardData!['todayClasses'] as List? ?? [];
      _todayClasses = rawToday.map((t) => TimetableSlot.fromJson(t)).toList();

      if (_dashboardData!['nextClass'] != null) {
        _nextClass = TimetableSlot.fromJson(_dashboardData!['nextClass']);
      } else {
        _nextClass = null;
      }

      _assignedBatches = _dashboardData!['assignedBatches'] as List? ?? [];
      _pendingReviewsCount = _dashboardData!['pendingReviewsCount'] ?? 0;
      _pendingDoubtsCount = _dashboardData!['pendingDoubtsCount'] ?? 0;
    } else {
      _errorMessage = response.error;
    }
    notifyListeners();
  }

  // Fetch Attendance Sheet for Batch & Subject
  Future<void> fetchAttendanceSheet(String batchId, String subjectId, String date) async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get('/api/attendance/batch/$batchId?subject_id=$subjectId&date=$date');
    _isLoading = false;

    if (response.success && response.data != null) {
      _attendanceSheet = response.data as List? ?? [];
    }
    notifyListeners();
  }

  // Save Batch Attendance
  Future<bool> saveBatchAttendance(
    String batchId,
    String subjectId,
    String date,
    List<Map<String, dynamic>> records,
  ) async {
    final response = await _api.post(ApiConstants.attendanceBatch, {
      'batch_id': batchId,
      'subject_id': subjectId,
      'date': date,
      'records': records,
    });

    if (response.success) {
      await fetchDashboard();
      return true;
    }
    return false;
  }

  // Fetch Assignments Created by Teacher
  Future<void> fetchAssignments() async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get(ApiConstants.assignmentsMy);
    _isLoading = false;

    if (response.success && response.data != null) {
      final list = response.data as List? ?? [];
      _assignments = list.map((a) => AssignmentModel.fromJson(a)).toList();
    }
    notifyListeners();
  }

  // Create Assignment
  Future<bool> createAssignment({
    required String title,
    required String subjectId,
    required String batchId,
    required String deadline,
    required String description,
    int maxMarks = 100,
    String? instructions,
  }) async {
    final response = await _api.post(ApiConstants.assignments, {
      'title': title,
      'subject_id': subjectId,
      'batch_id': batchId,
      'deadline': deadline,
      'description': description,
      'max_marks': maxMarks,
      'instructions': instructions,
    });

    if (response.success) {
      await fetchAssignments();
      return true;
    }
    return false;
  }

  // Fetch Submissions for an Assignment
  Future<void> fetchSubmissions(String assignmentId) async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get('/api/assignments/$assignmentId/submissions');
    _isLoading = false;

    if (response.success && response.data != null) {
      final list = response.data as List? ?? [];
      _submissions = list.map((s) => AssignmentSubmissionModel.fromJson(s)).toList();
    }
    notifyListeners();
  }

  // Grade Submission
  Future<bool> gradeSubmission(String submissionId, int marks, String feedback) async {
    final response = await _api.put('/api/assignments/submissions/$submissionId/grade', {
      'marks': marks,
      'feedback': feedback,
    });
    return response.success;
  }

  // Fetch Assigned Doubts
  Future<void> fetchAssignedDoubts() async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get(ApiConstants.doubtsAssigned);
    _isLoading = false;

    if (response.success && response.data != null) {
      final list = response.data as List? ?? [];
      _assignedDoubts = list.map((d) => DoubtModel.fromJson(d)).toList();
    }
    notifyListeners();
  }

  // Reply to Student Doubt
  Future<bool> respondToDoubt(String doubtId, String message, {String? attachmentUrl}) async {
    final response = await _api.post('/api/doubts/$doubtId/respond', {
      'message': message,
      'attachment_url': attachmentUrl,
    });
    if (response.success) {
      await fetchAssignedDoubts();
      return true;
    }
    return false;
  }

  // Upload Study Material
  Future<bool> uploadStudyMaterial({
    required String title,
    required String subjectId,
    required String classId,
    String? batchId,
    String? chapter,
    required String fileUrl,
    String? description,
  }) async {
    final response = await _api.post(ApiConstants.materials, {
      'title': title,
      'subject_id': subjectId,
      'class_id': classId,
      'batch_id': batchId,
      'chapter': chapter,
      'file_url': fileUrl,
      'description': description,
    });
    return response.success;
  }
}
