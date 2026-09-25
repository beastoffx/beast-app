import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/app_card.dart';
import 'teacher_attendance_screen.dart';
import 'teacher_assignments_screen.dart';
import 'teacher_doubts_screen.dart';
import 'teacher_results_screen.dart';
import '../common/notices_screen.dart';
import '../common/profile_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final teacher = Provider.of<TeacherProvider>(context);
    final teacherName = auth.user?.name ?? 'Faculty Member';

    if (teacher.isLoading && teacher.dashboardData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final nextClass = teacher.nextClass;
    final todayClasses = teacher.todayClasses;
    final pendingReviews = teacher.dashboardData?['pendingReviews'] as List? ?? [];
    final pendingDoubts = teacher.dashboardData?['pendingDoubts'] as List? ?? [];
    final notices = teacher.dashboardData?['recentNotices'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: () => teacher.fetchDashboard(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Faculty Header Banner
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
                      'FACULTY WORKSPACE',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome, $teacherName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${todayClasses.length} lectures scheduled today • ${teacher.pendingReviewsCount} submissions to review',
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
                        child: const Icon(Icons.school, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UPCOMING CLASS TODAY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.info,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${nextClass.subjectName} • Batch ${nextClass.batchName}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${nextClass.startTime} - ${nextClass.endTime} • ${nextClass.roomNumber}',
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

              // ACTIONABLE STATS TILES
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAssignmentsScreen())),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pending Reviews', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              Icon(Icons.assignment_late_outlined, size: 18, color: AppColors.warning),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${teacher.pendingReviewsCount}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text('Student submissions awaiting marks', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDoubtsScreen())),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Student Doubts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              Icon(Icons.question_answer_outlined, size: 18, color: AppColors.secondary),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${teacher.pendingDoubtsCount}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text('Questions awaiting faculty reply', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // FACULTY QUICK ACTIONS
              const Text(
                'Faculty Operations',
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
                  _buildActionTile(
                    icon: Icons.how_to_reg,
                    label: 'Take Attendance',
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAttendanceScreen())),
                  ),
                  _buildActionTile(
                    icon: Icons.post_add,
                    label: 'Assignments',
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAssignmentsScreen())),
                  ),
                  _buildActionTile(
                    icon: Icons.question_answer,
                    label: 'DoubtDeck Q&A',
                    color: Colors.amber.shade800,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDoubtsScreen())),
                  ),
                  _buildActionTile(
                    icon: Icons.grade,
                    label: 'Enter Results',
                    color: Colors.deepPurple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherResultsScreen())),
                  ),
                  _buildActionTile(
                    icon: Icons.campaign_outlined,
                    label: 'Notice Board',
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
                  ),
                  _buildActionTile(
                    icon: Icons.person_outline,
                    label: 'Faculty Profile',
                    color: Colors.blueGrey,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  ),
                ],
              ),
              // PENDING SUBMISSIONS TO REVIEW
              if (pendingReviews.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Submissions Awaiting Grading',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAssignmentsScreen())),
                      child: const Text('Review All', style: TextStyle(fontSize: 13, color: AppColors.primaryLight)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...pendingReviews.map((sub) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAssignmentsScreen())),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sub['student_name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                Text('${sub['assignment_title']} • Submitted: ${sub['submitted_at']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAssignmentsScreen())),
                              style: ElevatedButton.styleFrom(minimumSize: const Size(64, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                              child: const Text('Grade', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
              ],

              // RECENT DOUBTS AWAITING RESPONSE
              if (pendingDoubts.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Unresolved Student Doubts',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDoubtsScreen())),
                      child: const Text('View All', style: TextStyle(fontSize: 13, color: AppColors.primaryLight)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...pendingDoubts.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherDoubtsScreen())),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryLight.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.help_center, size: 20, color: AppColors.secondary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['title'] ?? 'Doubt',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${d['student_name']} • ${d['subject_name']}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
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

  Widget _buildActionTile({
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
