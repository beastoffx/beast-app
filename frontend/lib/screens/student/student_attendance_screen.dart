import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../widgets/app_card.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchAttendance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance Record'),
      ),
      body: student.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => student.fetchAttendance(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overall Percentage Card
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      color: student.overallAttendance >= 75 ? AppColors.surface : AppColors.errorLight,
                      child: Column(
                        children: [
                          const Text(
                            'OVERALL ATTENDANCE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${student.overallAttendance}%',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: student.overallAttendance >= 75 ? AppColors.success : AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: student.overallAttendance >= 75
                                  ? AppColors.successLight
                                  : AppColors.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              student.overallAttendance >= 75
                                  ? 'Satisfies 75% institutional requirement'
                                  : 'Warning: Below mandatory 75% threshold',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: student.overallAttendance >= 75 ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SUBJECT-WISE BREAKDOWN
                    const Text(
                      'Subject-wise Breakdown',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    if (student.subjectAttendance.isEmpty)
                      const AppCard(
                        padding: EdgeInsets.all(16),
                        child: Text('No subject attendance recorded yet.', textAlign: TextAlign.center),
                      )
                    else
                      ...student.subjectAttendance.map((sub) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      sub.subjectName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    Text(
                                      '${sub.percentage}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: sub.percentage >= 75 ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (sub.percentage / 100).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: AppColors.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      sub.percentage >= 75 ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Attended ${sub.presentCount + sub.lateCount} of ${sub.totalClasses} classes',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 20),

                    // RECENT ATTENDANCE HISTORY
                    const Text(
                      'Recent Attendance Log',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    if (student.recentAttendance.isEmpty)
                      const AppCard(
                        padding: EdgeInsets.all(16),
                        child: Text('No individual attendance logs found.', textAlign: TextAlign.center),
                      )
                    else
                      ...student.recentAttendance.map((rec) {
                        Widget badge;
                        if (rec.isPresent) {
                          badge = StatusBadge.present();
                        } else if (rec.isLate) {
                          badge = StatusBadge.late();
                        } else if (rec.isAbsent) {
                          badge = StatusBadge.absent();
                        } else {
                          badge = const StatusBadge(
                            label: 'Excused',
                            backgroundColor: AppColors.surfaceElevated,
                            textColor: AppColors.textSecondary,
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rec.subjectName ?? 'Subject',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Date: ${rec.date}${rec.remarks != null ? " • ${rec.remarks}" : ""}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                badge,
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}
