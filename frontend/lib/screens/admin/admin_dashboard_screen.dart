import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/beast_components.dart';
import 'admin_batches_screen.dart';
import 'admin_timetable_screen.dart';
import 'admin_fees_screen.dart';
import 'admin_audit_screen.dart';
import 'admin_management_screen.dart';
import 'student_management_screen.dart';
import 'teacher_management_screen.dart';
import 'requests_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final admin = Provider.of<AdminProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final adminName = auth.fullName.isNotEmpty ? auth.fullName : 'Administrator';
    final isSuper = auth.isSuperAdmin;

    if (admin.isLoading && admin.actionableToday == null) {
      return const BeastLoadingState(message: 'Loading institutional dashboard...');
    }

    if (admin.errorMessage != null && admin.actionableToday == null) {
      return BeastErrorState(
        message: admin.errorMessage!,
        onRetry: () => admin.fetchDashboard(),
      );
    }

    final today = admin.actionableToday;
    final totals = admin.institutionTotals;
    final recentAudit = admin.recentAudit;

    final totalStudents = totals?['totalStudents'] ?? 0;
    final activeBatches = totals?['activeBatches'] ?? 0;
    final totalTeachers = totals?['totalTeachers'] ?? 0;
    final pendingRequests = today?['pendingRequests'] ?? 0;
    final totalCollected = totals?['totalFeeCollected'] ?? 0;
    final totalOverdue = totals?['totalFeeOverdue'] ?? 0;

    return RefreshIndicator(
      onRefresh: () => admin.fetchDashboard(),
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
                // 1. Institutional Header
                _buildHeaderCard(auth, adminName, isSuper),
                const SizedBox(height: BeastSpacing.lg),

                // 2. High-Impact Institutional Metrics
                _buildMetricCards(totalStudents, activeBatches, totalTeachers, pendingRequests, totalCollected, totalOverdue, context),
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
                            _buildQuickActions(context, isSuper),
                            const SizedBox(height: BeastSpacing.lg),
                            _buildActionableToday(today, context),
                          ],
                        ),
                      ),
                      const SizedBox(width: BeastSpacing.xl),
                      Expanded(
                        flex: 5,
                        child: _buildRecentAuditSection(recentAudit, context),
                      ),
                    ],
                  )
                else ...[
                  _buildActionableToday(today, context),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildQuickActions(context, isSuper),
                  const SizedBox(height: BeastSpacing.lg),
                  _buildRecentAuditSection(recentAudit, context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AuthProvider auth, String adminName, bool isSuper) {
    return BeastCard(
      padding: const EdgeInsets.all(BeastSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSuper ? 'EXECUTIVE INSTITUTIONAL GOVERNANCE' : 'CAMPUS OPERATIONS COMMAND',
                style: BeastTypography.label.copyWith(letterSpacing: 1.0),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuper ? BeastColors.dangerLight : BeastColors.peach200,
                  borderRadius: BorderRadius.circular(BeastRadius.full),
                ),
                child: Text(
                  isSuper ? 'SUPER ADMIN ACCESS' : 'ADMINISTRATOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSuper ? BeastColors.danger : BeastColors.dark900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BeastSpacing.md),
          Text(
            adminName,
            style: BeastTypography.display.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            'B.E.A.S.T ACADEMY — Unified Academic Operations & Compliance Ledger',
            style: BeastTypography.body.copyWith(color: BeastColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(
    dynamic totalStudents,
    dynamic activeBatches,
    dynamic totalTeachers,
    dynamic pendingRequests,
    dynamic totalCollected,
    dynamic totalOverdue,
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final cardWidth = isNarrow ? (constraints.maxWidth - BeastSpacing.md) / 2 : (constraints.maxWidth - (BeastSpacing.md * 3)) / 4;

        final items = [
          BeastStatCard(
            title: 'Enrolled Students',
            value: '$totalStudents',
            icon: Icons.people_outline_rounded,
            subtitle: 'Active Scholars',
            accentColor: BeastColors.peach400,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentManagementScreen())),
          ),
          BeastStatCard(
            title: 'Active Batches',
            value: '$activeBatches',
            icon: Icons.hub_outlined,
            subtitle: 'Academic Streams',
            accentColor: BeastColors.accentWarm,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBatchesScreen())),
          ),
          BeastStatCard(
            title: 'Faculty Members',
            value: '$totalTeachers',
            icon: Icons.school_outlined,
            subtitle: 'Teaching Staff',
            accentColor: BeastColors.peach300,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherManagementScreen())),
          ),
          BeastStatCard(
            title: 'Pending Requests',
            value: '$pendingRequests',
            icon: Icons.assignment_ind_outlined,
            subtitle: pendingRequests == 0 ? 'Queue Clear' : 'Review Required',
            accentColor: pendingRequests > 0 ? BeastColors.warning : BeastColors.success,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsManagementScreen())),
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

  Widget _buildActionableToday(Map<String, dynamic>? today, BuildContext context) {
    final pendingReqs = today?['pendingRequests'] ?? 0;
    final flaggedAttendance = today?['flaggedAttendanceBatches'] ?? 0;
    final overdueCount = today?['overdueFeeInstallments'] ?? 0;

    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BeastSectionHeader(title: 'Actionable Institutional Tasks'),
          const Divider(color: BeastColors.borderSubtle),
          const SizedBox(height: BeastSpacing.sm),
          _actionRow(
            icon: Icons.assignment_ind_outlined,
            title: '$pendingReqs Admission Applications in Queue',
            subtitle: 'Pending candidate verification by faculty or administration.',
            actionLabel: 'Review',
            onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsManagementScreen())),
          ),
          const Divider(color: BeastColors.borderSubtle, height: BeastSpacing.lg),
          _actionRow(
            icon: Icons.payments_outlined,
            title: '$overdueCount Overdue Fee Accounts',
            subtitle: 'Students with tuition installment balances requiring reminder notice.',
            actionLabel: 'Ledger',
            onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeesScreen())),
          ),
          const Divider(color: BeastColors.borderSubtle, height: BeastSpacing.lg),
          _actionRow(
            icon: Icons.checklist_rounded,
            title: '$flaggedAttendance Batches Missing Daily Roll-Call',
            subtitle: 'Classes where scheduled session attendance was not recorded.',
            actionLabel: 'Schedule',
            onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTimetableScreen())),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(BeastSpacing.sm + 2),
          decoration: BoxDecoration(
            color: BeastColors.surfaceWarm,
            borderRadius: BorderRadius.circular(BeastRadius.sm),
          ),
          child: Icon(icon, size: 20, color: BeastColors.dark900),
        ),
        const SizedBox(width: BeastSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: BeastTypography.bodyMedium),
              Text(subtitle, style: BeastTypography.caption),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isSuper) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operational Suites', style: BeastTypography.title),
          const SizedBox(height: BeastSpacing.md),
          Row(
            children: [
              Expanded(
                child: BeastActionCard(
                  icon: Icons.people_outline_rounded,
                  title: 'Students',
                  subtitle: 'Directory & lifecycle',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentManagementScreen())),
                ),
              ),
              const SizedBox(width: BeastSpacing.md),
              Expanded(
                child: BeastActionCard(
                  icon: Icons.school_outlined,
                  title: 'Faculty',
                  subtitle: 'Teachers directory',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherManagementScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: BeastSpacing.md),
          Row(
            children: [
              Expanded(
                child: BeastActionCard(
                  icon: Icons.account_tree_outlined,
                  title: 'Academics',
                  subtitle: 'Classes & Batches',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBatchesScreen())),
                ),
              ),
              const SizedBox(width: BeastSpacing.md),
              Expanded(
                child: BeastActionCard(
                  icon: Icons.calendar_month_outlined,
                  title: 'Timetable',
                  subtitle: 'Master schedule',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTimetableScreen())),
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
                  title: 'Finance',
                  subtitle: 'Fee collections',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeesScreen())),
                ),
              ),
              const SizedBox(width: BeastSpacing.md),
              Expanded(
                child: BeastActionCard(
                  icon: Icons.security_outlined,
                  title: 'Audit Logs',
                  subtitle: 'Security ledger',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAuditScreen())),
                ),
              ),
            ],
          ),
          if (isSuper) ...[
            const SizedBox(height: BeastSpacing.md),
            BeastActionCard(
              icon: Icons.admin_panel_settings_outlined,
              iconColor: BeastColors.danger,
              badgeColor: BeastColors.dangerLight,
              title: 'Administrator Directory',
              subtitle: 'Super Admin: Manage institutional credentials',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManagementScreen())),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentAuditSection(List<dynamic> recentAudit, BuildContext context) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BeastSectionHeader(
            title: 'Recent Compliance Audit Trail',
            action: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAuditScreen())),
              child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const Divider(color: BeastColors.borderSubtle),
          if (recentAudit.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: BeastSpacing.xl),
              child: Center(
                child: Text('No recent audit log entries recorded.', style: TextStyle(color: BeastColors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentAudit.take(5).length,
              separatorBuilder: (_, __) => const Divider(color: BeastColors.borderSubtle, height: 1),
              itemBuilder: (context, index) {
                final a = recentAudit[index];
                final action = a['action'] ?? 'ACTION';
                final actorName = a['actor_name'] ?? 'System';
                final createdAt = a['created_at']?.toString() ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: BeastSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: BeastColors.neutral100,
                          borderRadius: BorderRadius.circular(BeastRadius.xs),
                        ),
                        child: const Icon(Icons.history_rounded, size: 16, color: BeastColors.dark900),
                      ),
                      const SizedBox(width: BeastSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(action, style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('Actor: $actorName', style: BeastTypography.caption),
                          ],
                        ),
                      ),
                      if (createdAt.isNotEmpty)
                        Text(
                          createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt,
                          style: BeastTypography.caption,
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
}
