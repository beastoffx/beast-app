class AcademicSessionModel {
  final String id;
  final String name;
  final String startDate;
  final String endDate;
  final bool isCurrent;

  AcademicSessionModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
  });

  factory AcademicSessionModel.fromJson(Map<String, dynamic> json) {
    return AcademicSessionModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      isCurrent: (json['is_current'] == 1 || json['is_current'] == true),
    );
  }
}

class ClassModel {
  final String id;
  final String name;
  final String? stream;
  final String? description;

  ClassModel({
    required this.id,
    required this.name,
    this.stream,
    this.description,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      stream: json['stream'],
      description: json['description'],
    );
  }
}

class BatchModel {
  final String id;
  final String name;
  final String classId;
  final String academicSessionId;
  final int maxCapacity;
  final String? className;
  final String? classStream;
  final int studentCount;

  BatchModel({
    required this.id,
    required this.name,
    required this.classId,
    required this.academicSessionId,
    required this.maxCapacity,
    this.className,
    this.classStream,
    this.studentCount = 0,
  });

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    return BatchModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      classId: json['class_id'] ?? '',
      academicSessionId: json['academic_session_id'] ?? '',
      maxCapacity: json['max_capacity'] ?? 40,
      className: json['class_name'],
      classStream: json['class_stream'],
      studentCount: json['student_count'] ?? 0,
    );
  }
}

class SubjectModel {
  final String id;
  final String name;
  final String code;
  final String classId;
  final String? description;
  final String? className;

  SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.classId,
    this.description,
    this.className,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      classId: json['class_id'] ?? '',
      description: json['description'],
      className: json['class_name'],
    );
  }
}
