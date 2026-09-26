import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/beast_components.dart';
import 'student_timetable_screen.dart';
import 'student_attendance_screen.dart';
import 'student_assignments_screen.dart';
import 'student_materials_screen.dart';
import 'student_exams_screen.dart';
import 'student_doubts_screen.dart';
import 'student_fees_screen.dart';
import '../common/notices_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchDashboard();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
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
    final student = Provider.of<StudentProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final userName = auth.user?.name ?? 'Scholar';

    if (student.isLoading && student.dashboardData == null) {
      return const BeastLoadingState(message: 'Loading academic dashboard...');
    }

    if (student.errorMessage != null && student.dashboardData == null) {
      return BeastErrorState(
        message: student.errorMessage!,
        onRetry: () => student.fetchDashboard(),
      );
    }

    final data = student.dashboardData;
    final nextClass = student.nextClass;
    final todayClasses = student.todayClasses;
    final pendingAssignments = data?['pendingAssignments'] as List? ?? [];
    final recentNotices = data?['recentNotices'] as List? ?? [];
    final attendanceSummary = data?['attendanceSummary'] as Map<String, dynamic>?;

    final double attendancePct = (attendanceSummary?['percentage'] is num)
        ? (attendanceSummary!['percentage'] as num).toDouble()
        : 0.0;

    return RefreshIndicator(
      onRefresh: () => student.fetchDashboard(),
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
                // 1. Personalized Academic Welcome Card
                _buildHeroCard(auth, userName, todayClasses.length, pendingAssignments.length),
                const SizedBox(height: BeastSpacing.lg),

                // 2. High-Impact Academic Metric Cards
                _buildMetricCards(attendancePct, pendingAssignments.length, todayClasses.length, context),
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
                            _buildTodayScheduleSection(todayClasses, context),
                          ],
                        ),
                      ),
                      const SizedBox(width: BeastSpacing.xl),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildPendingAssignmentsSection(pendingAssignments, context),
                            const SizedBox(height: BeastSpacing.lg),
                            _buildNoticesSection(recentNotices, context),
                            const SizedBox(height: BeastSpacing.lg),
                            _buildQuickActions(context),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildNextClassSection(nextClass, context),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildTodayScheduleSection(todayClasses, context),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildPendingAssignmentsSection(pendingAssignments, context),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildNoticesSection(recentNotices, context),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildQuickActions(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(AuthProvider auth, String userName, int classCount, int assignmentCount) {
    final batchName = auth.studentProfile?.batchName ?? 'Enrolled Batch';

    return BeastCard(
      backgroundColor: BeastColors.white,
      borderColor: BeastColors.borderSubtle,
      boxShadow: BeastShadows.card,
      padding: const EdgeInsets.all(BeastSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getGreeting().toUpperCase()}, $userName',
                style: const TextStyle(
                  color: BeastColors.dark700,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BeastColors.peach200,
                  borderRadius: BorderRadius.circular(BeastRadius.full),
                ),
                child: Text(
                  batchName,
                  style: const TextStyle(
                    color: BeastColors.dark900,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BeastSpacing.md),
          Text(
            'Academic Overview & Schedule',
            style: BeastTypography.display.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            '$classCount scheduled lecture${classCount == 1 ? '' : 's'} today • $assignmentCount pending submission${assignmentCount == 1 ? '' : 's'} requiring attention',
            style: BeastTypography.body.copyWith(color: BeastColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(double attendancePct, int pendingAssignments, int todayLectures, BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final cardWidth = isNarrow ? (constraints.maxWidth - BeastSpacing.md) / 2 : (constraints.maxWidth - (BeastSpacing.md * 3)) / 4;

        final items = [
          BeastStatCard(
            title: 'Attendance',
            value: '${attendancePct.toStringAsFixed(1)}%',
            icon: Icons.verified_user_outlined,
            subtitle: attendancePct >= 75 ? 'Eligible' : 'Requires Attention',
            accentColor: attendancePct >= 75 ? BeastColors.success : BeastColors.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAttendanceScreen())),
          ),
          BeastStatCard(
            title: 'Pending Work',
            value: '$pendingAssignments',
            icon: Icons.assignment_outlined,
            subtitle: pendingAssignments == 0 ? 'All Caught Up' : 'Active Tasks',
            accentColor: pendingAssignments > 0 ? BeastColors.peach400 : BeastColors.neutral300,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen())),
          ),
          BeastStatCard(
            title: 'Today Classes',
            value: '$todayLectures',
            icon: Icons.calendar_today_outlined,
            subtitle: 'Scheduled',
            accentColor: BeastColors.accentWarm,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentTimetableScreen())),
          ),
          BeastStatCard(
            title: 'Doubt Desk',
            value: 'Q&A',
            icon: Icons.help_outline_rounded,
            subtitle: 'Faculty Support',
            accentColor: BeastColors.peach300,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDoubtsScreen())),
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentTimetableScreen())),
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
                      isLive ? 'CLASS IN PROGRESS' : 'UPCOMING LECTURE',
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
                  '${nextClass.startTime} - ${nextClass.endTime} • Room: ${nextClass.roomNumber ?? 'Room TBA'} • ${nextClass.teacherName ?? 'Assigned Faculty'}',
                  style: BeastTypography.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: BeastColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildTodayScheduleSection(List<dynamic> todayClasses, BuildContext context) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeastSectionHeader(
            title: "Today's Schedule",
            action: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentTimetableScreen())),
              child: const Text('Full Week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const Divider(color: BeastColors.borderSubtle),
          if (todayClasses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeastSpacing.xl),
              child: Center(
                child: Text('No classes scheduled for today.', style: TextStyle(color: BeastColors.textMuted)),
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
                            Text(
                              cls.subjectName ?? 'Subject',
                              style: BeastTypography.bodyMedium,
                            ),
                            Text(
                              '${cls.teacherName ?? 'Faculty'} • Room ${cls.roomNumber ?? 'TBA'}',
                              style: BeastTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      if (isLive)
                        const BeastBadge(
                          label: 'ONGOING',
                          backgroundColor: BeastColors.peach300,
                          textColor: BeastColors.dark900,
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPendingAssignmentsSection(List<dynamic> pendingAssignments, BuildContext context) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeastSectionHeader(
            title: 'Action Required: Assignments',
            action: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen())),
              child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const Divider(color: BeastColors.borderSubtle),
          if (pendingAssignments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeastSpacing.lg),
              child: Center(
                child: Text('No pending assignments. You are fully caught up!', style: TextStyle(color: BeastColors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingAssignments.take(3).length,
              separatorBuilder: (_, __) => const Divider(color: BeastColors.borderSubtle, height: 1),
              itemBuilder: (context, index) {
                final item = pendingAssignments[index];
                final title = item['title'] ?? 'Assignment';
                final subject = item['subject_name'] ?? 'Subject';
                final dueDate = item['due_date']?.toString() ?? '';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BeastColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(BeastRadius.xs),
                    ),
                    child: const Icon(Icons.assignment_late_outlined, size: 18, color: BeastColors.dark900),
                  ),
                  title: Text(title, style: BeastTypography.bodyMedium),
                  subtitle: Text('$subject • Due: ${dueDate.length >= 10 ? dueDate.substring(0, 10) : dueDate}', style: BeastTypography.caption),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: BeastColors.textMuted),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen())),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNoticesSection(List<dynamic> notices, BuildContext context) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeastSectionHeader(
            title: 'Recent Circulars',
            action: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
              child: const Text('All Notices', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const Divider(color: BeastColors.borderSubtle),
          if (notices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeastSpacing.lg),
              child: Center(
                child: Text('No announcements posted.', style: TextStyle(color: BeastColors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notices.take(3).length,
              separatorBuilder: (_, __) => const Divider(color: BeastColors.borderSubtle, height: 1),
              itemBuilder: (context, index) {
                final item = notices[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.campaign_outlined, size: 20, color: BeastColors.dark900),
                  title: Text(item['title'] ?? 'Notice', style: BeastTypography.bodyMedium),
                  subtitle: Text(item['created_at']?.toString().substring(0, 10) ?? '', style: BeastTypography.caption),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Access Portals', style: BeastTypography.title),
          const SizedBox(height: BeastSpacing.md),
          Row(
            children: [
              Expanded(
                child: BeastActionCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Study Materials',
                  subtitle: 'Lecture notes & PDFs',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentMaterialsScreen())),
                ),
              ),
              const SizedBox(width: BeastSpacing.md),
              Expanded(
                child: BeastActionCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'Exam Results',
                  subtitle: 'Scorecards & feedback',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentExamsScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: BeastSpacing.md),
          Row(
            children: [
              Expanded(
                child: BeastActionCard(
                  icon: Icons.payments_outlined,
                  title: 'Fee Ledger',
                  subtitle: 'Tuition records',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentFeesScreen())),
                ),
              ),
              const SizedBox(width: BeastSpacing.md),
              Expanded(
                child: BeastActionCard(
                  icon: Icons.help_outline_rounded,
                  title: 'Ask a Doubt',
                  subtitle: 'Faculty clarification',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDoubtsScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
