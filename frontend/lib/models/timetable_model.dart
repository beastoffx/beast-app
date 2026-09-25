class TimetableSlot {
  final String id;
  final String batchId;
  final String subjectId;
  final String teacherId;
  final int dayOfWeek; // 1: Mon .. 7: Sun
  final String startTime;
  final String endTime;
  final String roomNumber;
  final String? subjectName;
  final String? subjectCode;
  final String? teacherName;
  final String? batchName;

  TimetableSlot({
    required this.id,
    required this.batchId,
    required this.subjectId,
    required this.teacherId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.roomNumber,
    this.subjectName,
    this.subjectCode,
    this.teacherName,
    this.batchName,
  });

  factory TimetableSlot.fromJson(Map<String, dynamic> json) {
    return TimetableSlot(
      id: json['id'] ?? '',
      batchId: json['batch_id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      teacherId: json['teacher_id'] ?? '',
      dayOfWeek: json['day_of_week'] ?? 1,
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      roomNumber: json['room_number'] ?? 'Hall 1',
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      teacherName: json['teacher_name'],
      batchName: json['batch_name'],
    );
  }

  String get dayName {
    switch (dayOfWeek) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Day $dayOfWeek';
    }
  }

  String get shortDayName {
    switch (dayOfWeek) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return 'D$dayOfWeek';
    }
  }
}
