class DoubtModel {
  final String id;
  final String studentId;
  final String subjectId;
  final String? batchId;
  final String title;
  final String? topic;
  final String note;
  final String? imageUrl;
  final String status; // 'open', 'seen', 'in_discussion', 'answered', 'resolved'
  final String priority; // 'low', 'normal', 'high'
  final String? createdAt;
  final String? subjectName;
  final String? subjectCode;
  final String? studentName;
  final String? batchName;
  final int responseCount;

  DoubtModel({
    required this.id,
    required this.studentId,
    required this.subjectId,
    this.batchId,
    required this.title,
    this.topic,
    required this.note,
    this.imageUrl,
    required this.status,
    required this.priority,
    this.createdAt,
    this.subjectName,
    this.subjectCode,
    this.studentName,
    this.batchName,
    this.responseCount = 0,
  });

  factory DoubtModel.fromJson(Map<String, dynamic> json) {
    return DoubtModel(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      batchId: json['batch_id'],
      title: json['title'] ?? '',
      topic: json['topic'],
      note: json['note'] ?? '',
      imageUrl: json['image_url'],
      status: json['status'] ?? 'open',
      priority: json['priority'] ?? 'normal',
      createdAt: json['created_at'],
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      studentName: json['student_name'],
      batchName: json['batch_name'],
      responseCount: json['response_count'] ?? 0,
    );
  }

  bool get isResolved => status == 'resolved';
  bool get isOpen => status == 'open';
  bool get isAnswered => status == 'answered';
}

class DoubtResponseModel {
  final String id;
  final String doubtId;
  final String authorId;
  final String role; // 'teacher', 'student', 'admin'
  final String message;
  final String? attachmentUrl;
  final String? createdAt;
  final String? authorName;
  final String? authorRole;

  DoubtResponseModel({
    required this.id,
    required this.doubtId,
    required this.authorId,
    required this.role,
    required this.message,
    this.attachmentUrl,
    this.createdAt,
    this.authorName,
    this.authorRole,
  });

  factory DoubtResponseModel.fromJson(Map<String, dynamic> json) {
    return DoubtResponseModel(
      id: json['id'] ?? '',
      doubtId: json['doubt_id'] ?? '',
      authorId: json['author_id'] ?? '',
      role: json['role'] ?? 'teacher',
      message: json['message'] ?? '',
      attachmentUrl: json['attachment_url'],
      createdAt: json['created_at'],
      authorName: json['author_name'],
      authorRole: json['author_role'],
    );
  }
}
