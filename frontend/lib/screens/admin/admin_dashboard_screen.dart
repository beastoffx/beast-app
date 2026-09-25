import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_card.dart';
import 'admin_batches_screen.dart';
import 'admin_timetable_screen.dart';
import 'admin_fees_screen.dart';
import 'admin_audit_screen.dart';
import '../common/notices_screen.dart';
import '../common/profile_screen.dart';

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
    final adminName = auth.user?.name ?? 'Academy Director';

    if (admin.isLoading && admin.actionableToday == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final today = admin.actionableToday;
    final totals = admin.institutionTotals;
    final recentAudit = admin.recentAudit;

    return RefreshIndicator(
      onRefresh: () => admin.fetchDashboard(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Admin Master Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INSTITUTIONAL ADMINISTRATION',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      adminName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'B.E.A.S.T ACADEMY — Unified Digital Control Suite',
                      style: TextStyle(color: AppColors.surfaceElevated, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ACTIONABLE TODAY PANEL (Section 9 Compliance)
              const Text(
                'TODAY: Actionable Institutional State',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Lectures Scheduled', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('${today?['classesScheduled'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          const Text('Classes running today', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppCard(
                      color: (today?['attendancePending'] ?? 0) > 0 ? AppColors.warningLight : AppColors.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Attendance Pending', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            '${today?['attendancePending'] ?? 0}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.warning),
                          ),
                          const SizedBox(height: 4),
                          const Text('Batches awaiting log', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Submissions to Review', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('${today?['assignmentsPendingReview'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          const Text('Assignments submitted', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Open Doubts', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('${today?['openDoubts'] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.secondary)),
                          const SizedBox(height: 4),
                          const Text('Unanswered by faculty', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // INSTITUTION TOTALS STRIP
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTotalItem('Students', totals?['totalStudents']?.toString() ?? '0'),
                    _buildTotalItem('Faculty', totals?['totalTeachers']?.toString() ?? '0'),
                    _buildTotalItem('Batches', totals?['totalBatches']?.toString() ?? '0'),
                    _buildTotalItem('Classes', totals?['totalClasses']?.toString() ?? '0'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ADMINISTRATIVE MANAGEMENT MODULES
              const Text(
                'Institutional Management Suites',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 4 : 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  _buildAdminTile(
                    icon: Icons.hub_outlined,
                    label: 'Batches & Classes',
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBatchesScreen())),
                  ),
                  _buildAdminTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Timetable Builder',
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTimetableScreen())),
                  ),
                  _buildAdminTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Fee Ledger',
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeesScreen())),
                  ),
                  _buildAdminTile(
                    icon: Icons.campaign_outlined,
                    label: 'Notices Board',
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
                  ),
                  _buildAdminTile(
                    icon: Icons.security_outlined,
                    label: 'Audit Trail',
                    color: Colors.deepPurple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAuditScreen())),
                  ),
                  _buildAdminTile(
                    icon: Icons.person_outline,
                    label: 'Admin Profile',
                    color: Colors.blueGrey,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // RECENT AUDIT TRAIL LOGS
              if (recentAudit.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Administrative Audit Trail',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAuditScreen())),
                      child: const Text('View All', style: TextStyle(fontSize: 13, color: AppColors.primaryLight)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...recentAudit.map((log) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(
                          children: [
                            const Icon(Icons.history_edu, size: 20, color: AppColors.primaryLight),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log['action'] ?? 'ACTION',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    'By ${log['user_name'] ?? "Admin"} • ${log['created_at']}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.primary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildAdminTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
