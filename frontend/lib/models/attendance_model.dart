class AttendanceRecord {
  final String id;
  final String batchId;
  final String subjectId;
  final String studentId;
  final String date;
  final String status; // 'present', 'absent', 'late', 'excused'
  final String? remarks;
  final String? subjectName;
  final String? markedByName;

  AttendanceRecord({
    required this.id,
    required this.batchId,
    required this.subjectId,
    required this.studentId,
    required this.date,
    required this.status,
    this.remarks,
    this.subjectName,
    this.markedByName,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? '',
      batchId: json['batch_id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      studentId: json['student_id'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'present',
      remarks: json['remarks'],
      subjectName: json['subject_name'],
      markedByName: json['marked_by_name'],
    );
  }

  bool get isPresent => status == 'present';
  bool get isLate => status == 'late';
  bool get isAbsent => status == 'absent';
  bool get isExcused => status == 'excused';
}

class SubjectAttendance {
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final int totalClasses;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final double percentage;

  SubjectAttendance({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.totalClasses,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.percentage,
  });

  factory SubjectAttendance.fromJson(Map<String, dynamic> json) {
    return SubjectAttendance(
      subjectId: json['subject_id'] ?? '',
      subjectName: json['subject_name'] ?? '',
      subjectCode: json['subject_code'] ?? '',
      totalClasses: json['total_classes'] ?? 0,
      presentCount: json['present_count'] ?? 0,
      lateCount: json['late_count'] ?? 0,
      absentCount: json['absent_count'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
