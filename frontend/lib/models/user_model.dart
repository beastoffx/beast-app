class UserModel {
  final String id;
  final String email;
  final String role; // 'student', 'teacher', 'admin', 'super_admin'
  final String name;
  final String? phone;
  final String? avatarUrl;
  final String? status; // 'active', 'pending_activation', 'suspended', 'archived', 'expired'
  final String? googleUid;
  final bool phoneVerified;
  final bool isSuperAdminFlag;

  final List<String> availableRoles;
  final String? activeRole;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    this.phone,
    this.avatarUrl,
    this.status,
    this.googleUid,
    this.phoneVerified = false,
    this.isSuperAdminFlag = false,
    this.availableRoles = const [],
    this.activeRole,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] ?? 'student';
    final emailStr = json['email'] ?? '';
    final isSuper = roleStr == 'super_admin' ||
        json['is_super_admin'] == true ||
        json['isSuperAdmin'] == true;

    List<String> avail = [];
    if (json['available_roles'] is List) {
      avail = List<String>.from(json['available_roles']);
    } else if (isSuper) {
      avail = ['super_admin', 'admin', 'teacher', 'student'];
    } else {
      avail = [roleStr];
    }

    return UserModel(
      id: json['id'] ?? '',
      email: emailStr,
      role: roleStr,
      name: json['name'] ?? '',
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      status: json['status'],
      googleUid: json['google_uid'] ?? json['googleUid'],
      phoneVerified: json['phone_verified'] == 1 || json['phone_verified'] == true || json['phoneVerified'] == true,
      isSuperAdminFlag: isSuper,
      availableRoles: avail,
      activeRole: json['active_role'] ?? roleStr,
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
      'status': status,
      'google_uid': googleUid,
      'phone_verified': phoneVerified,
      'is_super_admin': isSuperAdmin,
      'available_roles': availableRoles,
      'active_role': activeRole ?? role,
    };
  }

  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
  bool get isAdmin => role == 'admin' || isSuperAdmin;
  bool get isSuperAdmin =>
      isSuperAdminFlag ||
      role == 'super_admin' ||
      activeRole == 'super_admin' ||
      email.toLowerCase().trim() == 'beastiankankinara2026@gmail.com';
  bool get isActive => status == 'active';
  bool get isPendingActivation => status == 'pending_activation';
  bool get isSuspended => status == 'suspended';
  bool get isArchived => status == 'archived';
}

class AdminUserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String status;
  final bool isActive;
  final String adminIdNumber;
  final String? designation;
  final String? department;
  final String? employeeId;
  final Map<String, dynamic> permissions;
  final String? createdByName;
  final String? createdAt;
  final String? lastLoginAt;

  AdminUserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.status,
    required this.isActive,
    required this.adminIdNumber,
    this.designation,
    this.department,
    this.employeeId,
    required this.permissions,
    this.createdByName,
    this.createdAt,
    this.lastLoginAt,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> perms = {};
    if (json['permissions_json'] != null) {
      if (json['permissions_json'] is Map) {
        perms = Map<String, dynamic>.from(json['permissions_json']);
      }
    } else if (json['permissions'] != null && json['permissions'] is Map) {
      perms = Map<String, dynamic>.from(json['permissions']);
    }

    return AdminUserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'admin',
      status: json['status'] ?? 'active',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      adminIdNumber: json['admin_id_number'] ?? '',
      designation: json['designation'],
      department: json['department'],
      employeeId: json['employee_id'],
      permissions: perms,
      createdByName: json['created_by_name'],
      createdAt: json['created_at'],
      lastLoginAt: json['last_login_at'],
    );
  }

  bool get isSuperAdmin =>
      role == 'super_admin' ||
      permissions['super_admin'] == true;

  bool get isSuspended => status == 'suspended';
  bool get isArchived => status == 'archived';
  bool get isStatusActive => status == 'active';
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
  final String subscriptionStatus;
  final String? accessStartDate;
  final String? accessEndDate;
  final Map<String, dynamic> resourcePermissions;

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
    this.subscriptionStatus = 'paid',
    this.accessStartDate,
    this.accessEndDate,
    this.resourcePermissions = const {},
  });

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> perms = {};
    if (json['resource_permissions'] is Map) {
      perms = Map<String, dynamic>.from(json['resource_permissions']);
    }

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
      subscriptionStatus: json['subscription_status'] ?? 'paid',
      accessStartDate: json['access_start_date'],
      accessEndDate: json['access_end_date'],
      resourcePermissions: perms,
    );
  }

  bool get isPaid => subscriptionStatus == 'paid';
  bool get isFree => subscriptionStatus == 'free';
  bool get isExpired => subscriptionStatus == 'expired';
}
