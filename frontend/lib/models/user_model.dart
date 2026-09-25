class UserModel {
  final String id;
  final String email;
  final String role; // 'student', 'teacher', 'admin'
  final String name;
  final String? phone;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.phone,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      name: json['name'] ?? '',
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'name': name,
      'phone': phone,
      'avatar_url': avatarUrl,
    };
  }

  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
  bool get isAdmin => role == 'admin';
}

class StudentProfileModel {
  final String id;
  final String userId;
  final String studentIdNumber;
  final String? classId;
  final String? batchId;
  final String? className;
  final String? batchName;
  final String? sessionName;
  final String? emergencyContact;

  StudentProfileModel({
    required this.id,
    required this.userId,
    required this.studentIdNumber,
    this.classId,
    this.batchId,
    this.className,
    this.batchName,
    this.sessionName,
    this.emergencyContact,
  });

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      studentIdNumber: json['student_id_number'] ?? '',
      classId: json['class_id'],
      batchId: json['batch_id'],
      className: json['class_name'],
      batchName: json['batch_name'],
      sessionName: json['session_name'],
      emergencyContact: json['emergency_contact'],
    );
  }
}
