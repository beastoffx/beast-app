import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../models/academic_models.dart';
import '../models/fee_exam_model.dart';
import '../models/material_notice_model.dart';

class AdminProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Admin Dashboard
  Map<String, dynamic>? _actionableToday;
  Map<String, dynamic>? _institutionTotals;
  List<dynamic> _recentAudit = [];
  List<dynamic> _recentNotices = [];

  Map<String, dynamic>? get actionableToday => _actionableToday;
  Map<String, dynamic>? get institutionTotals => _institutionTotals;
  List<dynamic> get recentAudit => _recentAudit;
  List<dynamic> get recentNotices => _recentNotices;

  // Academics lists
  List<AcademicSessionModel> _sessions = [];
  List<ClassModel> _classes = [];
  List<BatchModel> _batches = [];
  List<SubjectModel> _subjects = [];
  List<dynamic> _students = [];
  List<dynamic> _teachers = [];
  List<dynamic> _teacherAssignments = [];

  List<AcademicSessionModel> get sessions => _sessions;
  List<ClassModel> get classes => _classes;
  List<BatchModel> get batches => _batches;
  List<SubjectModel> get subjects => _subjects;
  List<dynamic> get students => _students;
  List<dynamic> get teachers => _teachers;
  List<dynamic> get teacherAssignments => _teacherAssignments;

  // Fees
  List<FeeRecordModel> _fees = [];
  Map<String, dynamic>? _feeStats;
  List<FeeRecordModel> get fees => _fees;
  Map<String, dynamic>? get feeStats => _feeStats;

  // Notices
  List<NoticeModel> _notices = [];
  List<NoticeModel> get notices => _notices;

  // Audit Logs
  List<dynamic> _auditLogs = [];
  List<dynamic> get auditLogs => _auditLogs;

  // Fetch Admin Dashboard
  Future<void> fetchDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.get(ApiConstants.adminDashboard);
    _isLoading = false;

    if (response.success && response.data != null) {
      _actionableToday = response.data['actionableToday'];
      _institutionTotals = response.data['institutionTotals'];
      _recentAudit = response.data['recentAudit'] as List? ?? [];
      _recentNotices = response.data['recentNotices'] as List? ?? [];
    } else {
      _errorMessage = response.error;
    }
    notifyListeners();
  }

  // Fetch Academics
  Future<void> fetchAcademics() async {
    _isLoading = true;
    notifyListeners();

    final sessionsRes = await _api.get(ApiConstants.academicsSessions);
    if (sessionsRes.success && sessionsRes.data != null) {
      final list = sessionsRes.data as List? ?? [];
      _sessions = list.map((s) => AcademicSessionModel.fromJson(s)).toList();
    }

    final classesRes = await _api.get(ApiConstants.academicsClasses);
    if (classesRes.success && classesRes.data != null) {
      final list = classesRes.data as List? ?? [];
      _classes = list.map((c) => ClassModel.fromJson(c)).toList();
    }

    final batchesRes = await _api.get(ApiConstants.academicsBatches);
    if (batchesRes.success && batchesRes.data != null) {
      final list = batchesRes.data as List? ?? [];
      _batches = list.map((b) => BatchModel.fromJson(b)).toList();
    }

    final subjectsRes = await _api.get(ApiConstants.academicsSubjects);
    if (subjectsRes.success && subjectsRes.data != null) {
      final list = subjectsRes.data as List? ?? [];
      _subjects = list.map((s) => SubjectModel.fromJson(s)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Create Batch
  Future<bool> createBatch(String name, String classId, String sessionId, {int maxCapacity = 40}) async {
    final res = await _api.post(ApiConstants.academicsBatches, {
      'name': name,
      'class_id': classId,
      'academic_session_id': sessionId,
      'max_capacity': maxCapacity,
    });
    if (res.success) {
      await fetchAcademics();
      return true;
    }
    return false;
  }

  // Create Class
  Future<bool> createClass(String name, String stream, String description) async {
    final res = await _api.post(ApiConstants.academicsClasses, {
      'name': name,
      'stream': stream,
      'description': description,
    });
    if (res.success) {
      await fetchAcademics();
      return true;
    }
    return false;
  }

  // Create Subject
  Future<bool> createSubject(String name, String code, String classId, String description) async {
    final res = await _api.post(ApiConstants.academicsSubjects, {
      'name': name,
      'code': code,
      'class_id': classId,
      'description': description,
    });
    if (res.success) {
      await fetchAcademics();
      return true;
    }
    return false;
  }

  // Fetch Users (Students & Teachers)
  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();

    final stuRes = await _api.get(ApiConstants.academicsStudents);
    if (stuRes.success && stuRes.data != null) {
      _students = stuRes.data as List? ?? [];
    }

    final tchRes = await _api.get(ApiConstants.academicsTeachers);
    if (tchRes.success && tchRes.data != null) {
      _teachers = tchRes.data as List? ?? [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Create Student
  Future<bool> createStudent({
    required String name,
    required String email,
    required String password,
    required String studentIdNumber,
    required String classId,
    required String batchId,
    required String sessionId,
    String? phone,
    String? emergencyContact,
  }) async {
    final res = await _api.post(ApiConstants.academicsStudents, {
      'name': name,
      'email': email,
      'password': password,
      'student_id_number': studentIdNumber,
      'class_id': classId,
      'batch_id': batchId,
      'academic_session_id': sessionId,
      'phone': phone,
      'emergency_contact': emergencyContact,
    });
    if (res.success) {
      await fetchUsers();
      return true;
    }
    return false;
  }

  // Create Teacher
  Future<bool> createTeacher({
    required String name,
    required String email,
    required String password,
    required String employeeCode,
    String? qualification,
    String? bio,
    String? phone,
  }) async {
    final res = await _api.post(ApiConstants.academicsTeachers, {
      'name': name,
      'email': email,
      'password': password,
      'employee_code': employeeCode,
      'qualification': qualification,
      'bio': bio,
      'phone': phone,
    });
    if (res.success) {
      await fetchUsers();
      return true;
    }
    return false;
  }

  // Assign Teacher to Batch and Subject
  Future<bool> assignTeacher(String teacherId, String batchId, String subjectId, String sessionId) async {
    final res = await _api.post(ApiConstants.academicsTeacherAssignments, {
      'teacher_id': teacherId,
      'batch_id': batchId,
      'subject_id': subjectId,
      'academic_session_id': sessionId,
    });
    return res.success;
  }

  // Schedule Timetable Slot
  Future<ApiResponse<dynamic>> scheduleSlot({
    required String batchId,
    required String subjectId,
    required String teacherId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String roomNumber = 'Hall 1',
  }) async {
    return await _api.post(ApiConstants.timetable, {
      'batch_id': batchId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'room_number': roomNumber,
    });
  }

  // Fetch Fees
  Future<void> fetchFees({String? status}) async {
    _isLoading = true;
    notifyListeners();

    String endpoint = ApiConstants.fees;
    if (status != null) {
      endpoint += '?status=$status';
    }

    final res = await _api.get(endpoint);
    _isLoading = false;

    if (res.success && res.data != null) {
      final records = res.data['records'] as List? ?? [];
      _fees = records.map((f) => FeeRecordModel.fromJson(f)).toList();
      _feeStats = res.data['stats'];
    }
    notifyListeners();
  }

  // Record Fee Payment
  Future<bool> recordFeePayment(String feeId, double paidAmount, {String? notes}) async {
    final res = await _api.put('/api/fees/$feeId/record-payment', {
      'paid_amount': paidAmount,
      'notes': notes,
    });
    if (res.success) {
      await fetchFees();
      return true;
    }
    return false;
  }

  // Publish Notice
  Future<bool> publishNotice({
    required String title,
    required String description,
    required String category,
    String priority = 'medium',
    String targetType = 'all',
    String? targetId,
    bool isPinned = false,
  }) async {
    final res = await _api.post(ApiConstants.notices, {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'target_type': targetType,
      'target_id': targetId,
      'is_pinned': isPinned,
    });
    return res.success;
  }

  // Fetch Audit Logs
  Future<void> fetchAuditLogs() async {
    _isLoading = true;
    notifyListeners();

    final res = await _api.get(ApiConstants.auditLogs);
    _isLoading = false;

    if (res.success && res.data != null) {
      _auditLogs = res.data as List? ?? [];
    }
    notifyListeners();
  }
}
