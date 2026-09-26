import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/app_card.dart';
import 'student_timetable_screen.dart';
import 'student_attendance_screen.dart';
import 'student_assignments_screen.dart';
import 'student_materials_screen.dart';
import 'student_exams_screen.dart';
import 'student_doubts_screen.dart';
import 'student_fees_screen.dart';
import '../common/notices_screen.dart';
import '../common/profile_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final student = Provider.of<StudentProvider>(context);
    final userName = auth.user?.name ?? 'Scholar';

    if (student.isLoading && student.dashboardData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = student.dashboardData;
    final nextClass = student.nextClass;
    final todayClasses = student.todayClasses;
    final pendingAssignments = data?['pendingAssignments'] as List? ?? [];
    final recentNotices = data?['recentNotices'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: () => student.fetchDashboard(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting & Daily Focus Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_getGreeting().toUpperCase()}, $userName',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            auth.studentProfile?.batchName ?? 'PCM-2027-A',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'What do I need to do today?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${todayClasses.length} lectures scheduled • ${pendingAssignments.length} pending assignments',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // NEXT CLASS HIGHLIGHT
              if (nextClass != null) ...[
                AppCard(
                  color: AppColors.infoLight,
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.timer_outlined, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NEXT LECTURE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.info,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextClass.subjectName ?? 'Subject',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${nextClass.startTime} - ${nextClass.endTime} • ${nextClass.roomNumber} • ${nextClass.teacherName}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // KEY STATS TILES (Attendance & Open Doubts)
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAttendanceScreen())),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Attendance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              Icon(Icons.pie_chart_outline, size: 18, color: student.overallAttendance >= 75 ? AppColors.success : AppColors.error),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${student.overallAttendance}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: student.overallAttendance >= 75 ? AppColors.success : AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student.overallAttendance >= 75 ? 'Above 75% threshold' : 'Attendance alert',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDoubtsScreen())),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('DoubtDeck', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              Icon(Icons.question_answer_outlined, size: 18, color: AppColors.secondary),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${data?['openDoubtsCount'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Active academic doubts', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // QUICK ACTIONS GRID
              const Text(
                'Academic Quick Actions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
                  _buildQuickActionTile(
                    icon: Icons.calendar_month,
                    label: 'Timetable',
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentTimetableScreen())),
                  ),
                  _buildQuickActionTile(
                    icon: Icons.assignment_outlined,
                    label: 'Assignments',
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen())),
                  ),
                  _buildQuickActionTile(
                    icon: Icons.menu_book_outlined,
                    label: 'Materials',
                    color: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentMaterialsScreen())),
                  ),
                  _buildQuickActionTile(
                    icon: Icons.fact_check_outlined,
                    label: 'Exams & Marks',
                    color: Colors.deepPurple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentExamsScreen())),
                  ),
                  _buildQuickActionTile(
                    icon: Icons.campaign_outlined,
                    label: 'Notices',
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
                  ),
                  _buildQuickActionTile(
                    icon: Icons.help_outline,
                    label: 'DoubtDeck',
                    color: Colors.amber.shade800,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDoubtsScreen())),
                  ),
                  _buildQuickActionTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Fee Ledger',
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentFeesScreen())),
                  ),
                  _buildQuickActionTile(
                    icon: Icons.person_outline,
                    label: 'My Profile',
                    color: Colors.blueGrey,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // PENDING ASSIGNMENTS SUMMARY
              if (pendingAssignments.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pending Assignments',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen())),
                      child: const Text('View All', style: TextStyle(fontSize: 13, color: AppColors.primaryLight)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...pendingAssignments.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen())),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.assignment_late, size: 20, color: AppColors.warning),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['title'] ?? 'Assignment',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${a['subject_name']} • Due: ${a['deadline']}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const StatusBadge(
                              label: 'Pending',
                              backgroundColor: AppColors.warningLight,
                              textColor: AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
              ],

              // RECENT NOTICES
              if (recentNotices.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Important Notices',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
                      child: const Text('All Notices', style: TextStyle(fontSize: 13, color: AppColors.primaryLight)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...recentNotices.map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (n['is_pinned'] == 1)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.push_pin, size: 14, color: AppColors.secondary),
                                  ),
                                Expanded(
                                  child: Text(
                                    n['title'] ?? 'Notice',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (n['priority'] == 'urgent') ? AppColors.errorLight : AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    (n['category'] ?? 'general').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: (n['priority'] == 'urgent') ? AppColors.error : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n['description'] ?? '',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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

  Widget _buildQuickActionTile({
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
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
