import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../models/timetable_model.dart';
import '../models/attendance_model.dart';
import '../models/assignment_model.dart';
import '../models/material_notice_model.dart';
import '../models/doubt_model.dart';
import '../models/fee_exam_model.dart';

class StudentProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isOffline = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;

  // Dashboard Data
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? get dashboardData => _dashboardData;

  // Timetable
  List<TimetableSlot> _schedule = [];
  List<TimetableSlot> _todayClasses = [];
  TimetableSlot? _nextClass;
  List<TimetableSlot> get schedule => _schedule;
  List<TimetableSlot> get todayClasses => _todayClasses;
  TimetableSlot? get nextClass => _nextClass;

  // Attendance
  double _overallAttendance = 0.0;
  List<SubjectAttendance> _subjectAttendance = [];
  List<AttendanceRecord> _recentAttendance = [];
  double get overallAttendance => _overallAttendance;
  List<SubjectAttendance> get subjectAttendance => _subjectAttendance;
  List<AttendanceRecord> get recentAttendance => _recentAttendance;

  // Assignments
  List<AssignmentModel> _assignments = [];
  List<AssignmentModel> get assignments => _assignments;

  // Materials & Notices
  List<StudyMaterialModel> _materials = [];
  List<NoticeModel> _notices = [];
  List<StudyMaterialModel> get materials => _materials;
  List<NoticeModel> get notices => _notices;

  // Exams & Results
  List<ExamModel> _exams = [];
  List<ResultModel> _results = [];
  Map<String, dynamic>? _resultsSummary;
  List<ExamModel> get exams => _exams;
  List<ResultModel> get results => _results;
  Map<String, dynamic>? get resultsSummary => _resultsSummary;

  // Doubts (DoubtDeck)
  List<DoubtModel> _allDoubts = [];
  List<DoubtModel> _openDoubts = [];
  List<DoubtModel> _resolvedDoubts = [];
  List<DoubtModel> get allDoubts => _allDoubts;
  List<DoubtModel> get openDoubts => _openDoubts;
  List<DoubtModel> get resolvedDoubts => _resolvedDoubts;

  // Fees
  List<FeeRecordModel> _fees = [];
  Map<String, dynamic>? _feeSummary;
  List<FeeRecordModel> get fees => _fees;
  Map<String, dynamic>? get feeSummary => _feeSummary;

  // Fetch complete student dashboard
  Future<void> fetchDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.get(ApiConstants.studentDashboard);
    _isLoading = false;
    _isOffline = response.isFromCache;

    if (response.success && response.data != null) {
      _dashboardData = response.data;
      _overallAttendance = (_dashboardData!['attendancePercentage'] as num?)?.toDouble() ?? 0.0;

      final rawToday = _dashboardData!['todayClasses'] as List? ?? [];
      _todayClasses = rawToday.map((t) => TimetableSlot.fromJson(t)).toList();

      if (_dashboardData!['nextClass'] != null) {
        _nextClass = TimetableSlot.fromJson(_dashboardData!['nextClass']);
      } else {
        _nextClass = null;
      }
    } else {
      _errorMessage = response.error;
    }
    notifyListeners();
  }

  // Fetch full timetable
  Future<void> fetchTimetable() async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get(ApiConstants.timetableMy);
    _isLoading = false;
    _isOffline = response.isFromCache;

    if (response.success && response.data != null) {
      final list = response.data['schedule'] as List? ?? [];
      _schedule = list.map((s) => TimetableSlot.fromJson(s)).toList();
    }
    notifyListeners();
  }

  // Fetch attendance details
  Future<void> fetchAttendance() async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get(ApiConstants.attendanceMy);
    _isLoading = false;
    _isOffline = response.isFromCache;

    if (response.success && response.data != null) {
      _overallAttendance = (response.data['overallPercentage'] as num?)?.toDouble() ?? 0.0;
      final rawSub = response.data['subjectBreakdown'] as List? ?? [];
      _subjectAttendance = rawSub.map((s) => SubjectAttendance.fromJson(s)).toList();

      final rawRec = response.data['recentRecords'] as List? ?? [];
      _recentAttendance = rawRec.map((r) => AttendanceRecord.fromJson(r)).toList();
    }
    notifyListeners();
  }

  // Fetch assignments
  Future<void> fetchAssignments() async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get(ApiConstants.assignmentsMy);
    _isLoading = false;
    _isOffline = response.isFromCache;

    if (response.success && response.data != null) {
      final list = response.data as List? ?? [];
      _assignments = list.map((a) => AssignmentModel.fromJson(a)).toList();
    }
    notifyListeners();
  }

  // Submit assignment
  Future<bool> submitAssignment(String assignmentId, String notes, {String? fileUrl}) async {
    final response = await _api.post('/api/assignments/$assignmentId/submit', {
      'notes': notes,
      'file_url': fileUrl,
    });
    if (response.success) {
      await fetchAssignments();
      return true;
    }
    return false;
  }

  // Fetch materials
  Future<void> fetchMaterials({String? subjectId, String? chapter}) async {
    _isLoading = true;
    notifyListeners();

    String endpoint = ApiConstants.materials;
    if (subjectId != null) {
      endpoint += '?subject_id=$subjectId';
    }

    final response = await _api.get(endpoint);
    _isLoading = false;
    _isOffline = response.isFromCache;

    if (response.success && response.data != null) {
      final list = response.data as List? ?? [];
      _materials = list.map((m) => StudyMaterialModel.fromJson(m)).toList();
    }
    notifyListeners();
  }

  // Fetch notices
  Future<void> fetchNotices() async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get(ApiConstants.notices);
    _isLoading = false;
    _isOffline = response.isFromCache;

    if (response.success && response.data != null) {
      final list = response.data as List? ?? [];
      _notices = list.map((n) => NoticeModel.fromJson(n)).toList();
    }
    notifyListeners();
  }

  // Fetch exams and results
  Future<void> fetchExamsAndResults() async {
    _isLoading = true;
    notifyListeners();

    final examsRes = await _api.get(ApiConstants.exams);
    if (examsRes.success && examsRes.data != null) {
      final list = examsRes.data as List? ?? [];
      _exams = list.map((e) => ExamModel.fromJson(e)).toList();
    }

    final resultsRes = await _api.get(ApiConstants.resultsMy);
    if (resultsRes.success && resultsRes.data != null) {
      final rawResults = resultsRes.data['results'] as List? ?? [];
      _results = rawResults.map((r) => ResultModel.fromJson(r)).toList();
      _resultsSummary = resultsRes.data['summary'];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fetch Doubts (DoubtDeck)
  Future<void> fetchDoubts() async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get(ApiConstants.doubtsMy);
    _isLoading = false;
    _isOffline = response.isFromCache;

    if (response.success && response.data != null) {
      final rawAll = response.data['all'] as List? ?? [];
      _allDoubts = rawAll.map((d) => DoubtModel.fromJson(d)).toList();
      _openDoubts = _allDoubts.where((d) => !d.isResolved).toList();
      _resolvedDoubts = _allDoubts.where((d) => d.isResolved).toList();
    }
    notifyListeners();
  }

  // Create Doubt
  Future<bool> createDoubt({
    required String subjectId,
    required String title,
    String? topic,
    required String note,
    String? imageUrl,
    String priority = 'normal',
  }) async {
    final response = await _api.post(ApiConstants.doubts, {
      'subject_id': subjectId,
      'title': title,
      'topic': topic,
      'note': note,
      'image_url': imageUrl,
      'priority': priority,
    });

    if (response.success) {
      await fetchDoubts();
      return true;
    }
    return false;
  }

  // Resolve Doubt
  Future<bool> resolveDoubt(String doubtId, bool isResolved) async {
    final response = await _api.put('/api/doubts/$doubtId/resolve', {
      'is_resolved': isResolved,
    });
    if (response.success) {
      await fetchDoubts();
      return true;
    }
    return false;
  }

  // Fetch Fees
  Future<void> fetchFees() async {
    _isLoading = true;
    notifyListeners();

    final response = await _api.get(ApiConstants.feesMy);
    _isLoading = false;
    _isOffline = response.isFromCache;

    if (response.success && response.data != null) {
      final rawFees = response.data['fees'] as List? ?? [];
      _fees = rawFees.map((f) => FeeRecordModel.fromJson(f)).toList();
      _feeSummary = response.data['summary'];
    }
    notifyListeners();
  }
}
