class StudyMaterialModel {
  final String id;
  final String title;
  final String? description;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final String subjectId;
  final String? batchId;
  final String classId;
  final String? chapter;
  final String teacherId;
  final String? subjectName;
  final String? subjectCode;
  final String? className;
  final String? batchName;
  final String? teacherName;
  final String? createdAt;

  StudyMaterialModel({
    required this.id,
    required this.title,
    this.description,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.subjectId,
    this.batchId,
    required this.classId,
    this.chapter,
    required this.teacherId,
    this.subjectName,
    this.subjectCode,
    this.className,
    this.batchName,
    this.teacherName,
    this.createdAt,
  });

  factory StudyMaterialModel.fromJson(Map<String, dynamic> json) {
    return StudyMaterialModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? 'application/pdf',
      fileSize: json['file_size'] ?? 0,
      subjectId: json['subject_id'] ?? '',
      batchId: json['batch_id'],
      classId: json['class_id'] ?? '',
      chapter: json['chapter'] ?? 'General',
      teacherId: json['teacher_id'] ?? '',
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      className: json['class_name'],
      batchName: json['batch_name'],
      teacherName: json['teacher_name'],
      createdAt: json['created_at'],
    );
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class NoticeModel {
  final String id;
  final String title;
  final String description;
  final String category; // 'academic', 'exam', 'class', 'holiday', 'general', 'urgent'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String? attachmentUrl;
  final String targetType;
  final String? targetId;
  final String authorId;
  final String publishDate;
  final bool isPinned;
  final String? authorName;
  final String? authorRole;

  NoticeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    this.attachmentUrl,
    required this.targetType,
    this.targetId,
    required this.authorId,
    required this.publishDate,
    required this.isPinned,
    this.authorName,
    this.authorRole,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'general',
      priority: json['priority'] ?? 'medium',
      attachmentUrl: json['attachment_url'],
      targetType: json['target_type'] ?? 'all',
      targetId: json['target_id'],
      authorId: json['author_id'] ?? '',
      publishDate: json['publish_date'] ?? '',
      isPinned: (json['is_pinned'] == 1 || json['is_pinned'] == true),
      authorName: json['author_name'],
      authorRole: json['author_role'],
    );
  }

  bool get isUrgent => priority == 'urgent' || category == 'urgent';
}
