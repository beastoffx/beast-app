import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/beast_components.dart';
import 'teacher_attendance_screen.dart';
import 'teacher_assignments_screen.dart';
import 'teacher_doubts_screen.dart';
import 'teacher_results_screen.dart';
import 'teacher_requests_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TeacherProvider>(context, listen: false).fetchDashboard();
    });
  }

  bool _isClassOngoing(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return false;
    try {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;

      final startParts = startTime.split(':').map((p) => int.parse(p.trim())).toList();
      final endParts = endTime.split(':').map((p) => int.parse(p.trim())).toList();

      final startMinutes = startParts[0] * 60 + startParts[1];
      final endMinutes = endParts[0] * 60 + endParts[1];

      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final teacher = Provider.of<TeacherProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final teacherName = auth.user?.name ?? 'Faculty Member';

    if (teacher.isLoading && teacher.dashboardData == null) {
      return const BeastLoadingState(message: 'Loading faculty dashboard...');
    }

    if (teacher.errorMessage != null && teacher.dashboardData == null) {
      return BeastErrorState(
        message: teacher.errorMessage!,
        onRetry: () => teacher.fetchDashboard(),
      );
    }

    final nextClass = teacher.nextClass;
    final todayClasses = teacher.todayClasses;
    final pendingReviews = teacher.dashboardData?['pendingReviews'] as List? ?? [];
    final pendingDoubts = teacher.dashboardData?['pendingDoubts'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: () => teacher.fetchDashboard(),
      color: BeastColors.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Faculty Welcome Card
                _buildHeroCard(auth, teacherName, todayClasses.length, teacher.pendingReviewsCount, teacher.pendingDoubtsCount),
                const SizedBox(height: BeastSpacing.lg),

                // 2. Metric KPI Cards
                _buildMetricCards(todayClasses.length, teacher.pendingDoubtsCount, teacher.pendingReviewsCount, context),
                const SizedBox(height: BeastSpacing.xl),

                // 3. Desktop 2-Column or Mobile Vertical
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildNextClassSection(nextClass, context),
                            const SizedBox(height: BeastSpacing.lg),
                            _buildTodayTeachingSection(todayClasses, context),
                          ],
                        ),
                      ),
                      const SizedBox(width: BeastSpacing.xl),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildQuickActionCards(context),
                            const SizedBox(height: BeastSpacing.lg),
                            _buildPendingDoubtsSection(pendingDoubts, context),
                            const SizedBox(height: BeastSpacing.lg),
                            _buildPendingReviewsSection(pendingReviews, context),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildNextClassSection(nextClass, context),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildTodayTeachingSection(todayClasses, context),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildQuickActionCards(context),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildPendingDoubtsSection(pendingDoubts, context),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildPendingReviewsSection(pendingReviews, context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(AuthProvider auth, String teacherName, int classesCount, int reviewsCount, int doubtsCount) {
    return BeastCard(
      padding: const EdgeInsets.all(BeastSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FACULTY COCKPIT',
                style: BeastTypography.label.copyWith(letterSpacing: 1.0),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BeastColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(BeastRadius.full),
                ),
                child: Text(
                  '${auth.user?.role ?? "TEACHER"} PORTAL',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: BeastColors.dark900),
                ),
              ),
            ],
          ),
          const SizedBox(height: BeastSpacing.md),
          Text(
            'Welcome, $teacherName',
            style: BeastTypography.display.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            '$classesCount scheduled class${classesCount == 1 ? '' : 'es'} today • $doubtsCount student doubt${doubtsCount == 1 ? '' : 's'} awaiting clarification • $reviewsCount submission${reviewsCount == 1 ? '' : 's'} to grade',
            style: BeastTypography.body.copyWith(color: BeastColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(int classesToday, int openDoubts, int ungradedWork, BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final cardWidth = isNarrow ? (constraints.maxWidth - BeastSpacing.md) / 2 : (constraints.maxWidth - (BeastSpacing.md * 3)) / 4;

        final items = [
          BeastStatCard(
            title: 'Lectures Today',
            value: '$classesToday',
            icon: Icons.calendar_today_outlined,
            subtitle: 'Scheduled Roster',
            accentColor: BeastColors.peach400,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen())),
          ),
          BeastStatCard(
            title: 'Unanswered Doubts',
            value: '$openDoubts',
            icon: Icons.question_answer_outlined,
            subtitle: openDoubts == 0 ? 'Inbox Clear' : 'Attention Required',
            accentColor: openDoubts > 0 ? BeastColors.warning : BeastColors.success,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDoubtsScreen())),
          ),
          BeastStatCard(
            title: 'To Grade',
            value: '$ungradedWork',
            icon: Icons.assignment_turned_in_outlined,
            subtitle: 'Submissions',
            accentColor: BeastColors.accentWarm,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAssignmentsScreen())),
          ),
          BeastStatCard(
            title: 'Admission Queue',
            value: 'Review',
            icon: Icons.how_to_reg_outlined,
            subtitle: 'Verification Desk',
            accentColor: BeastColors.peach300,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherRequestsScreen())),
          ),
        ];

        return Wrap(
          spacing: BeastSpacing.md,
          runSpacing: BeastSpacing.md,
          children: items.map((widget) => SizedBox(width: cardWidth, child: widget)).toList(),
        );
      },
    );
  }

  Widget _buildNextClassSection(dynamic nextClass, BuildContext context) {
    if (nextClass == null) return const SizedBox.shrink();

    final isLive = _isClassOngoing(nextClass.startTime, nextClass.endTime);

    return BeastCard(
      backgroundColor: isLive ? BeastColors.peach100 : BeastColors.white,
      borderColor: isLive ? BeastColors.peach400 : BeastColors.borderSubtle,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen())),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(BeastSpacing.md),
            decoration: BoxDecoration(
              color: isLive ? BeastColors.brandPrimary : BeastColors.surfaceWarm,
              borderRadius: BorderRadius.circular(BeastRadius.sm),
            ),
            child: Icon(
              isLive ? Icons.sensors_rounded : Icons.schedule_rounded,
              color: isLive ? BeastColors.white : BeastColors.dark900,
              size: 24,
            ),
          ),
          const SizedBox(width: BeastSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isLive ? 'ACTIVE LECTURE NOW' : 'UPCOMING TEACHING SESSION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isLive ? BeastColors.danger : BeastColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLive)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: BeastColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  nextClass.subjectName ?? 'Subject',
                  style: BeastTypography.headline.copyWith(fontSize: 17),
                ),
                Text(
                  '${nextClass.startTime} - ${nextClass.endTime} • Batch: ${nextClass.batchName ?? "Assigned Batch"} • Room: ${nextClass.roomNumber ?? "TBA"}',
                  style: BeastTypography.caption,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.checklist_rounded, size: 16),
            label: const Text('Attendance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BeastColors.brandPrimary,
              foregroundColor: BeastColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTeachingSection(List<dynamic> todayClasses, BuildContext context) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeastSectionHeader(
            title: "Today's Teaching Schedule",
            action: TextButton.icon(
              icon: const Icon(Icons.how_to_reg_outlined, size: 16),
              label: const Text('Mark Roll-Call'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen())),
            ),
          ),
          const Divider(color: BeastColors.borderSubtle),
          if (todayClasses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeastSpacing.xl),
              child: Center(
                child: Text('No lectures assigned for today.', style: TextStyle(color: BeastColors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todayClasses.length,
              separatorBuilder: (_, __) => const Divider(color: BeastColors.borderSubtle, height: 1),
              itemBuilder: (context, index) {
                final cls = todayClasses[index];
                final isLive = _isClassOngoing(cls.startTime, cls.endTime);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: BeastSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLive ? BeastColors.brandPrimary : BeastColors.neutral100,
                          borderRadius: BorderRadius.circular(BeastRadius.xs),
                        ),
                        child: Text(
                          cls.startTime ?? '--:--',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isLive ? BeastColors.white : BeastColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: BeastSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cls.subjectName ?? 'Subject', style: BeastTypography.bodyMedium),
                            Text('Batch: ${cls.batchName ?? "PCM"} • Room ${cls.roomNumber ?? "TBA"}', style: BeastTypography.caption),
                          ],
                        ),
                      ),
                      if (isLive)
                        const BeastBadge(label: 'ONGOING', backgroundColor: BeastColors.peach300, textColor: BeastColors.dark900),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCards(BuildContext context) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Faculty Operations', style: BeastTypography.title),
          const SizedBox(height: BeastSpacing.md),
          Row(
            children: [
              Expanded(
                child: BeastActionCard(
                  icon: Icons.how_to_reg_outlined,
                  title: 'Attendance',
                  subtitle: 'Take batch roll-call',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen())),
                ),
              ),
              const SizedBox(width: BeastSpacing.md),
              Expanded(
                child: BeastActionCard(
                  icon: Icons.assignment_outlined,
                  title: 'Assignments',
                  subtitle: 'Create & grade work',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAssignmentsScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: BeastSpacing.md),
          Row(
            children: [
              Expanded(
                child: BeastActionCard(
                  icon: Icons.question_answer_outlined,
                  title: 'Doubts Inbox',
                  subtitle: 'Resolve student doubts',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDoubtsScreen())),
                ),
              ),
              const SizedBox(width: BeastSpacing.md),
              Expanded(
                child: BeastActionCard(
                  icon: Icons.grade_outlined,
                  title: 'Exam Results',
                  subtitle: 'Enter student marks',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherResultsScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDoubtsSection(List<dynamic> pendingDoubts, BuildContext context) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeastSectionHeader(
            title: 'Unanswered Student Doubts',
            action: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDoubtsScreen())),
              child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const Divider(color: BeastColors.borderSubtle),
          if (pendingDoubts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeastSpacing.lg),
              child: Center(
                child: Text('All doubts have been resolved. Excellent work!', style: TextStyle(color: BeastColors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingDoubts.take(3).length,
              separatorBuilder: (_, __) => const Divider(color: BeastColors.borderSubtle, height: 1),
              itemBuilder: (context, index) {
                final d = pendingDoubts[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline_rounded, color: BeastColors.warning),
                  title: Text(d['title'] ?? 'Doubt', style: BeastTypography.bodyMedium),
                  subtitle: Text('${d['subject_name'] ?? 'Subject'} • From: ${d['student_name'] ?? 'Student'}', style: BeastTypography.caption),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BeastColors.textMuted),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDoubtsScreen())),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPendingReviewsSection(List<dynamic> pendingReviews, BuildContext context) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeastSectionHeader(
            title: 'Ungraded Submissions',
            action: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAssignmentsScreen())),
              child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const Divider(color: BeastColors.borderSubtle),
          if (pendingReviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeastSpacing.lg),
              child: Center(
                child: Text('No submissions awaiting grading.', style: TextStyle(color: BeastColors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingReviews.take(3).length,
              separatorBuilder: (_, __) => const Divider(color: BeastColors.borderSubtle, height: 1),
              itemBuilder: (context, index) {
                final r = pendingReviews[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment_turned_in_outlined, color: BeastColors.dark900),
                  title: Text(r['title'] ?? 'Assignment', style: BeastTypography.bodyMedium),
                  subtitle: Text('${r['batch_name'] ?? 'Batch'} • ${r['pending_count'] ?? 1} submissions', style: BeastTypography.caption),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BeastColors.textMuted),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAssignmentsScreen())),
                );
              },
            ),
        ],
      ),
    );
  }
}
