class AssignmentModel {
  final String id;
  final String title;
  final String subjectId;
  final String batchId;
  final String teacherId;
  final String description;
  final String deadline;
  final int maxMarks;
  final String? attachmentUrl;
  final String? instructions;
  final String? subjectName;
  final String? subjectCode;
  final String? teacherName;
  final String? batchName;
  // Submission fields if requested by student
  final String? submissionId;
  final String? submissionStatus; // 'pending', 'submitted', 'late', 'reviewed'
  final String? submittedAt;
  final int? marksObtained;
  final String? feedback;
  final String? submissionFileUrl;

  AssignmentModel({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.batchId,
    required this.teacherId,
    required this.description,
    required this.deadline,
    required this.maxMarks,
    this.attachmentUrl,
    this.instructions,
    this.subjectName,
    this.subjectCode,
    this.teacherName,
    this.batchName,
    this.submissionId,
    this.submissionStatus,
    this.submittedAt,
    this.marksObtained,
    this.feedback,
    this.submissionFileUrl,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subjectId: json['subject_id'] ?? '',
      batchId: json['batch_id'] ?? '',
      teacherId: json['teacher_id'] ?? '',
      description: json['description'] ?? '',
      deadline: json['deadline'] ?? '',
      maxMarks: json['max_marks'] ?? 100,
      attachmentUrl: json['attachment_url'],
      instructions: json['instructions'],
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      teacherName: json['teacher_name'],
      batchName: json['batch_name'],
      submissionId: json['submission_id'],
      submissionStatus: json['submission_status'],
      submittedAt: json['submitted_at'],
      marksObtained: json['marks_obtained'] != null ? (json['marks_obtained'] as num).toInt() : null,
      feedback: json['feedback'],
      submissionFileUrl: json['submission_file_url'],
    );
  }

  bool get isSubmitted => submissionStatus != null && submissionStatus != 'pending';
  bool get isReviewed => submissionStatus == 'reviewed';
}

class AssignmentSubmissionModel {
  final String id;
  final String assignmentId;
  final String studentId;
  final String? fileUrl;
  final String? notes;
  final String submittedAt;
  final String status;
  final int? marks;
  final String? feedback;
  final String? studentName;
  final String? studentEmail;
  final String? studentIdNumber;

  AssignmentSubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    this.fileUrl,
    this.notes,
    required this.submittedAt,
    required this.status,
    this.marks,
    this.feedback,
    this.studentName,
    this.studentEmail,
    this.studentIdNumber,
  });

  factory AssignmentSubmissionModel.fromJson(Map<String, dynamic> json) {
    return AssignmentSubmissionModel(
      id: json['id'] ?? '',
      assignmentId: json['assignment_id'] ?? '',
      studentId: json['student_id'] ?? '',
      fileUrl: json['file_url'],
      notes: json['notes'],
      submittedAt: json['submitted_at'] ?? '',
      status: json['status'] ?? 'submitted',
      marks: json['marks'] != null ? (json['marks'] as num).toInt() : null,
      feedback: json['feedback'],
      studentName: json['student_name'],
      studentEmail: json['student_email'],
      studentIdNumber: json['student_id_number'],
    );
  }
}
