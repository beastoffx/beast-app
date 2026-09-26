import 'package:flutter_test/flutter_test.dart';
import 'package:beast_academy/models/user_model.dart';
import 'package:beast_academy/models/timetable_model.dart';
import 'package:beast_academy/models/attendance_model.dart';
import 'package:beast_academy/models/doubt_model.dart';
import 'package:beast_academy/models/fee_exam_model.dart';

void main() {
  group('B.E.A.S.T ACADEMY Domain Models Test Suite', () {
    test('UserModel role validation and serialization', () {
      final user = UserModel(
        id: 'user-001',
        email: 'student@beastacademy.edu',
        role: 'student',
        name: 'Aarav Mehta',
        phone: '+91 9876543210',
      );

      expect(user.isStudent, true);
      expect(user.isTeacher, false);
      expect(user.isAdmin, false);

      final json = user.toJson();
      expect(json['email'], 'student@beastacademy.edu');
      expect(json['role'], 'student');

      final restored = UserModel.fromJson(json);
      expect(restored.name, 'Aarav Mehta');
    });

    test('TimetableSlot weekday resolution', () {
      final slotMon = TimetableSlot(
        id: 'tt-1',
        batchId: 'b-1',
        subjectId: 's-1',
        teacherId: 't-1',
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '10:00',
        roomNumber: 'Hall Alpha',
      );
      expect(slotMon.dayName, 'Monday');
      expect(slotMon.shortDayName, 'Mon');

      final slotSat = TimetableSlot(
        id: 'tt-6',
        batchId: 'b-1',
        subjectId: 's-1',
        teacherId: 't-1',
        dayOfWeek: 6,
        startTime: '10:15',
        endTime: '11:45',
        roomNumber: 'Lab Beta',
      );
      expect(slotSat.dayName, 'Saturday');
      expect(slotSat.shortDayName, 'Sat');
    });

    test('AttendanceRecord and SubjectAttendance percentage calculations', () {
      final sub = SubjectAttendance(
        subjectId: 'sub-phy',
        subjectName: 'Physics',
        subjectCode: 'PHY-12',
        totalClasses: 20,
        presentCount: 16,
        lateCount: 2,
        absentCount: 2,
        percentage: 90.0,
      );

      expect(sub.totalClasses, 20);
      expect(sub.percentage, 90.0);

      final record = AttendanceRecord(
        id: 'att-1',
        batchId: 'b-1',
        subjectId: 's-1',
        studentId: 'st-1',
        date: '2026-09-26',
        status: 'present',
      );
      expect(record.isPresent, true);
      expect(record.isAbsent, false);
    });

    test('DoubtModel status lifecycle and DoubtDeck flow', () {
      final doubtOpen = DoubtModel(
        id: 'd-1',
        studentId: 'st-1',
        subjectId: 'sub-phy',
        title: 'Static friction torque condition',
        note: 'Why does static friction not dissipate mechanical energy during rolling?',
        status: 'open',
        priority: 'high',
      );
      expect(doubtOpen.isOpen, true);
      expect(doubtOpen.isResolved, false);

      final doubtResolved = DoubtModel(
        id: 'd-2',
        studentId: 'st-1',
        subjectId: 'sub-phy',
        title: 'Static friction torque condition',
        note: 'Understood now.',
        status: 'resolved',
        priority: 'normal',
      );
      expect(doubtResolved.isResolved, true);
      expect(doubtResolved.isOpen, false);
    });

    test('FeeRecord status helper logic', () {
      final feePaid = FeeRecordModel(
        id: 'fee-1',
        studentId: 'st-1',
        academicSessionId: 'sess-1',
        feeTitle: 'Term 1 Tuition Fee',
        amount: 25000.0,
        dueDate: '2026-05-15',
        status: 'paid',
        paidAmount: 25000.0,
        receiptReference: 'REC-001',
      );
      expect(feePaid.isPaid, true);
      expect(feePaid.isPending, false);

      final feePending = FeeRecordModel(
        id: 'fee-2',
        studentId: 'st-2',
        academicSessionId: 'sess-1',
        feeTitle: 'Term 1 Tuition Fee',
        amount: 25000.0,
        dueDate: '2026-05-15',
        status: 'pending',
        paidAmount: 0.0,
      );
      expect(feePending.isPaid, false);
      expect(feePending.isPending, true);
    });

    test('Super Admin role hierarchy and AdminUserModel lifecycle flags', () {
      // 1. Super Admin role resolution
      final superUser = UserModel(
        id: 'usr-super-01',
        email: 'beastiankankinara2026@gmail.com',
        role: 'super_admin',
        name: 'Super Admin',
      );
      expect(superUser.isAdmin, true);
      expect(superUser.isSuperAdmin, true);

      // 2. Ordinary Admin without super_admin privileges
      final subAdmin = UserModel(
        id: 'usr-admin-01',
        email: 'admin@beastacademy.edu',
        role: 'admin',
        name: 'Academic Administrator',
      );
      expect(subAdmin.isAdmin, true);
      expect(subAdmin.isSuperAdmin, false);

      // 3. AdminUserModel serialization and permissions
      final adminModel = AdminUserModel.fromJson({
        'id': 'usr-admin-02',
        'name': 'Rajesh Sharma',
        'email': 'rajesh.admin@beastacademy.edu',
        'role': 'admin',
        'status': 'active',
        'is_active': 1,
        'admin_id_number': 'ADM-2027-00002',
        'designation': 'Academic Operations Manager',
        'department': 'Academic Operations',
        'permissions_json': {
          'manage_students': true,
          'view_analytics': true,
          'super_admin': false,
        },
      });

      expect(adminModel.adminIdNumber, 'ADM-2027-00002');
      expect(adminModel.isStatusActive, true);
      expect(adminModel.isSuspended, false);
      expect(adminModel.isArchived, false);
      expect(adminModel.isSuperAdmin, false);
      expect(adminModel.permissions['manage_students'], true);

      // 4. StudentProfileModel subscription lifecycle
      final studentProfile = StudentProfileModel.fromJson({
        'id': 'stu-01',
        'user_id': 'usr-stu-01',
        'student_id_number': 'BST-2027-00001',
        'subscription_status': 'paid',
        'access_start_date': '2026-01-01',
        'access_end_date': '2027-12-31',
        'resource_permissions': {
          'materials': true,
          'exams': true,
          'live_lectures': true,
        },
      });

      expect(studentProfile.isPaid, true);
      expect(studentProfile.isFree, false);
      expect(studentProfile.isExpired, false);
      expect(studentProfile.resourcePermissions['exams'], true);
    });

    test('Student Activation and Google Sign-In UserModel attributes', () {
      final activatedStudent = UserModel(
        id: 'usr-activated-01',
        email: 'kabir@beastacademy.edu',
        role: 'student',
        name: 'Kabir Singhania',
        phone: '+91 98765 44444',
        googleUid: 'google-uid-kabir-01',
        phoneVerified: true,
        status: 'active',
      );

      expect(activatedStudent.isStudent, true);
      expect(activatedStudent.googleUid, 'google-uid-kabir-01');
      expect(activatedStudent.phoneVerified, true);
      expect(activatedStudent.status, 'active');
      expect(activatedStudent.isActive, true);
      expect(activatedStudent.isPendingActivation, false);

      final json = activatedStudent.toJson();
      expect(json['google_uid'], 'google-uid-kabir-01');
      expect(json['phone_verified'], true);
      expect(json['status'], 'active');

      final restored = UserModel.fromJson(json);
      expect(restored.name, 'Kabir Singhania');
      expect(restored.googleUid, 'google-uid-kabir-01');
      expect(restored.phoneVerified, true);
      expect(restored.isActive, true);
    });
  });
}
