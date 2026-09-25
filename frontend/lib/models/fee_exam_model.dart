class FeeRecordModel {
  final String id;
  final String studentId;
  final String academicSessionId;
  final String feeTitle;
  final double amount;
  final String dueDate;
  final String status; // 'paid', 'pending', 'partial', 'overdue'
  final double paidAmount;
  final String? paymentDate;
  final String? receiptReference;
  final String? notes;
  final String? sessionName;
  final String? studentName;
  final String? studentIdNumber;

  FeeRecordModel({
    required this.id,
    required this.studentId,
    required this.academicSessionId,
    required this.feeTitle,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.paidAmount,
    this.paymentDate,
    this.receiptReference,
    this.notes,
    this.sessionName,
    this.studentName,
    this.studentIdNumber,
  });

  factory FeeRecordModel.fromJson(Map<String, dynamic> json) {
    return FeeRecordModel(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      academicSessionId: json['academic_session_id'] ?? '',
      feeTitle: json['fee_title'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date'] ?? '',
      status: json['status'] ?? 'pending',
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: json['payment_date'],
      receiptReference: json['receipt_reference'],
      notes: json['notes'],
      sessionName: json['session_name'],
      studentName: json['student_name'],
      studentIdNumber: json['student_id_number'],
    );
  }

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isPartial => status == 'partial';
  bool get isOverdue => status == 'overdue';
}

class ExamModel {
  final String id;
  final String title;
  final String academicSessionId;
  final String? batchId;
  final String examType;
  final String startDate;
  final String endDate;
  final String? instructions;
  final String? batchName;
  final List<ExamSubjectModel> subjects;

  ExamModel({
    required this.id,
    required this.title,
    required this.academicSessionId,
    this.batchId,
    required this.examType,
    required this.startDate,
    required this.endDate,
    this.instructions,
    this.batchName,
    this.subjects = const [],
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    final rawSubjects = json['subjects'] as List? ?? [];
    return ExamModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      academicSessionId: json['academic_session_id'] ?? '',
      batchId: json['batch_id'],
      examType: json['exam_type'] ?? 'offline',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      instructions: json['instructions'],
      batchName: json['batch_name'],
      subjects: rawSubjects.map((s) => ExamSubjectModel.fromJson(s)).toList(),
    );
  }
}

class ExamSubjectModel {
  final String id;
  final String examId;
  final String subjectId;
  final String examDate;
  final String startTime;
  final int durationMinutes;
  final int maxMarks;
  final int passingMarks;
  final String? subjectName;
  final String? subjectCode;

  ExamSubjectModel({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.examDate,
    required this.startTime,
    required this.durationMinutes,
    required this.maxMarks,
    required this.passingMarks,
    this.subjectName,
    this.subjectCode,
  });

  factory ExamSubjectModel.fromJson(Map<String, dynamic> json) {
    return ExamSubjectModel(
      id: json['id'] ?? '',
      examId: json['exam_id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      examDate: json['exam_date'] ?? '',
      startTime: json['start_time'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 180,
      maxMarks: json['max_marks'] ?? 100,
      passingMarks: json['passing_marks'] ?? 35,
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
    );
  }
}

class ResultModel {
  final String id;
  final String examSubjectId;
  final String studentId;
  final double marksObtained;
  final double maxMarks;
  final double percentage;
  final String? grade;
  final String? feedback;
  final String? examTitle;
  final String? subjectName;
  final String? subjectCode;
  final String? examDate;

  ResultModel({
    required this.id,
    required this.examSubjectId,
    required this.studentId,
    required this.marksObtained,
    required this.maxMarks,
    required this.percentage,
    this.grade,
    this.feedback,
    this.examTitle,
    this.subjectName,
    this.subjectCode,
    this.examDate,
  });

  factory ResultModel.fromJson(Map<String, dynamic> json) {
    return ResultModel(
      id: json['id'] ?? '',
      examSubjectId: json['exam_subject_id'] ?? '',
      studentId: json['student_id'] ?? '',
      marksObtained: (json['marks_obtained'] as num?)?.toDouble() ?? 0.0,
      maxMarks: (json['max_marks'] as num?)?.toDouble() ?? 100.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade'],
      feedback: json['feedback'],
      examTitle: json['exam_title'],
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      examDate: json['exam_date'],
    );
  }
}
