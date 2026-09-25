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
  });
}
