import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/student_provider.dart';
import '../../widgets/beast_components.dart';

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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Attendance Register'),
      ),
      body: student.isLoading && student.attendanceRecords.isEmpty
          ? const BeastLoadingState(message: 'Loading attendance records...')
          : student.errorMessage != null && student.attendanceRecords.isEmpty
              ? BeastErrorState(
                  message: student.errorMessage!,
                  onRetry: () => student.fetchAttendance(),
                )
              : RefreshIndicator(
                  onRefresh: () => student.fetchAttendance(),
                  color: BeastColors.brandPrimary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(BeastSpacing.lg),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildSummaryCard(student),
                                        const SizedBox(height: BeastSpacing.lg),
                                        _buildSubjectBreakdown(student),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: BeastSpacing.xl),
                                  Expanded(
                                    flex: 6,
                                    child: _buildHistoryCard(student),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildSummaryCard(student),
                                  const SizedBox(height: BeastSpacing.lg),
                                  _buildSubjectBreakdown(student),
                                  const SizedBox(height: BeastSpacing.lg),
                                  _buildHistoryCard(student),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryCard(StudentProvider student) {
    final pct = student.overallAttendance;
    final isEligible = pct >= 75;

    // Calculate counts from records
    int present = 0;
    int lateCount = 0;
    int absent = 0;
    for (var r in student.attendanceRecords) {
      final st = (r.status).toLowerCase();
      if (st == 'present') present++;
      else if (st == 'late') lateCount++;
      else if (st == 'absent') absent++;
    }
    final total = student.attendanceRecords.length;

    return BeastCard(
      child: Column(
        children: [
          Text(
            'AGGREGATE ATTENDANCE',
            style: BeastTypography.label.copyWith(letterSpacing: 1.0),
          ),
          const SizedBox(height: BeastSpacing.md),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: BeastTypography.metricLarge.copyWith(
              color: isEligible ? BeastColors.success : BeastColors.danger,
            ),
          ),
          const SizedBox(height: BeastSpacing.sm),
          BeastBadge(
            label: isEligible ? 'SATISFIES 75% REQUIREMENT' : 'BELOW 75% MINIMUM REQUIREMENT',
            backgroundColor: isEligible ? BeastColors.successLight : BeastColors.dangerLight,
            textColor: isEligible ? BeastColors.success : BeastColors.danger,
            icon: isEligible ? Icons.check_circle_rounded : Icons.warning_rounded,
          ),
          const SizedBox(height: BeastSpacing.lg),
          const Divider(color: BeastColors.borderSubtle),
          const SizedBox(height: BeastSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCountColumn('Present', '$present', BeastColors.success),
              _buildCountColumn('Late', '$lateCount', BeastColors.warning),
              _buildCountColumn('Absent', '$absent', BeastColors.danger),
              _buildCountColumn('Total', '$total', BeastColors.dark900),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: BeastTypography.headline.copyWith(color: color, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: BeastTypography.caption),
      ],
    );
  }

  Widget _buildSubjectBreakdown(StudentProvider student) {
    final subjects = student.subjectAttendance;

    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BeastSectionHeader(title: 'Subject Breakdown'),
          const Divider(color: BeastColors.borderSubtle),
          if (subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeastSpacing.lg),
              child: Center(
                child: Text('No subject attendance data recorded.', style: TextStyle(color: BeastColors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
              itemBuilder: (ctx, i) {
                final sub = subjects[i];
                final subName = sub.subjectName;
                final double subPct = sub.percentage;
                final isOk = subPct >= 75;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(subName, style: BeastTypography.bodyMedium),
                        Text(
                          '${subPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isOk ? BeastColors.success : BeastColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (subPct / 100).clamp(0.0, 1.0),
                        backgroundColor: BeastColors.neutral100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOk ? BeastColors.success : BeastColors.danger,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(StudentProvider student) {
    final records = student.attendanceRecords;

    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BeastSectionHeader(title: 'Session Roll-Call Log'),
          const Divider(color: BeastColors.borderSubtle),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeastSpacing.xxl),
              child: BeastEmptyState(
                icon: Icons.checklist_rounded,
                title: 'No Session Records',
                message: 'Recorded class attendance logs will be displayed here in chronological order.',
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(color: BeastColors.borderSubtle, height: 1),
              itemBuilder: (ctx, i) {
                final r = records[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: BeastSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: BeastColors.neutral100,
                          borderRadius: BorderRadius.circular(BeastRadius.xs),
                        ),
                        child: Text(
                          r.date.length >= 10 ? r.date.substring(5, 10) : r.date,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BeastColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: BeastSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.subjectName ?? 'Subject', style: BeastTypography.bodyMedium),
                            if (r.remarks != null && r.remarks!.isNotEmpty)
                              Text(r.remarks!, style: BeastTypography.caption),
                          ],
                        ),
                      ),
                      BeastStatusBadge(status: r.status),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
