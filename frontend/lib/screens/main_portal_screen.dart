import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/beast_tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/beast_logo.dart';
import '../widgets/beast_tutorial.dart';
import '../widgets/responsive_layout.dart';
import 'auth/login_screen.dart';

// Student Screens
import 'student/student_home_screen.dart';
import 'student/student_timetable_screen.dart';
import 'student/student_attendance_screen.dart';
import 'student/student_assignments_screen.dart';
import 'student/student_materials_screen.dart';
import 'student/student_exams_screen.dart';
import 'student/student_fees_screen.dart';
import 'student/student_doubts_screen.dart';

// Teacher Screens
import 'teacher/teacher_home_screen.dart';
import 'teacher/teacher_attendance_screen.dart';
import 'teacher/teacher_assignments_screen.dart';
import 'teacher/teacher_doubts_screen.dart';
import 'teacher/teacher_results_screen.dart';
import 'teacher/teacher_requests_screen.dart';

// Admin Screens
import 'admin/admin_dashboard_screen.dart';
import 'admin/student_management_screen.dart';
import 'admin/teacher_management_screen.dart';
import 'admin/admin_batches_screen.dart';
import 'admin/admin_timetable_screen.dart';
import 'admin/admin_fees_screen.dart';
import 'admin/requests_management_screen.dart';
import 'admin/admin_audit_screen.dart';
import 'admin/admin_management_screen.dart';

// Shared Common Screens
import 'common/profile_screen.dart';
import 'common/notices_screen.dart';
import 'common/search_screen.dart';
import 'common/notifications_screen.dart';

class MainPortalScreen extends StatefulWidget {
  const MainPortalScreen({super.key});

  @override
  State<MainPortalScreen> createState() => _MainPortalScreenState();
}

class _MainPortalScreenState extends State<MainPortalScreen> {
  int _currentIndex = 0;
  bool _checkedTutorial = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedTutorial) {
      _checkedTutorial = true;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            BeastTutorial.showIfFirstTime(context, auth.role);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (auth.isStudent) {
      return _buildStudentPortal(auth);
    } else if (auth.isTeacher) {
      return _buildTeacherPortal(auth);
    } else {
      return _buildAdminPortal(auth);
    }
  }

  // ============================================================
  // STUDENT PORTAL
  // ============================================================
  Widget _buildStudentPortal(AuthProvider auth) {
    final List<Widget> pages = [
      const StudentHomeScreen(),
      const StudentTimetableScreen(),
      const StudentMaterialsScreen(),
      const StudentDoubtsScreen(),
      const ProfileScreen(),
    ];

    const destinations = [
      NavDestinationItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
      NavDestinationItem(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month_rounded, label: 'Timetable'),
      NavDestinationItem(icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book_rounded, label: 'Materials'),
      NavDestinationItem(icon: Icons.help_outline_rounded, selectedIcon: Icons.help_rounded, label: 'Doubts'),
      NavDestinationItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
    ];

    return ResponsiveScaffold(
      title: 'Student Portal',
      selectedIndex: _currentIndex.clamp(0, pages.length - 1),
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: destinations,
      drawer: _buildStudentDrawer(context, auth),
      actions: _buildCommonActions(context, auth),
      body: IndexedStack(index: _currentIndex.clamp(0, pages.length - 1), children: pages),
    );
  }

  Widget _buildStudentDrawer(BuildContext context, AuthProvider auth) {
    return Drawer(
      backgroundColor: BeastColors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(auth, 'Student Workspace'),
          _buildSectorSwitchSection(context, auth),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Attendance Register'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAttendanceScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Coursework & Assignments'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Exams & Report Cards'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentExamsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Tuition Fees & Ledger'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentFeesScreen()));
            },
          ),
          const Divider(color: BeastColors.borderSubtle),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Campus Circulars'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: const Text('Platform Tour / Guide'),
            onTap: () {
              Navigator.pop(context);
              BeastTutorial.replay(context, 'STUDENT');
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEACHER PORTAL
  // ============================================================
  Widget _buildTeacherPortal(AuthProvider auth) {
    final List<Widget> pages = [
      const TeacherHomeScreen(),
      const TeacherAttendanceScreen(),
      const TeacherAssignmentsScreen(),
      const TeacherDoubtsScreen(),
      const ProfileScreen(),
    ];

    const destinations = [
      NavDestinationItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Overview'),
      NavDestinationItem(icon: Icons.how_to_reg_outlined, selectedIcon: Icons.how_to_reg_rounded, label: 'Attendance'),
      NavDestinationItem(icon: Icons.assignment_outlined, selectedIcon: Icons.assignment_rounded, label: 'Assignments'),
      NavDestinationItem(icon: Icons.question_answer_outlined, selectedIcon: Icons.question_answer_rounded, label: 'Doubts'),
      NavDestinationItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
    ];

    return ResponsiveScaffold(
      title: 'Faculty Workspace',
      selectedIndex: _currentIndex.clamp(0, pages.length - 1),
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: destinations,
      drawer: _buildTeacherDrawer(context, auth),
      actions: _buildCommonActions(context, auth),
      body: IndexedStack(index: _currentIndex.clamp(0, pages.length - 1), children: pages),
    );
  }

  Widget _buildTeacherDrawer(BuildContext context, AuthProvider auth) {
    return Drawer(
      backgroundColor: BeastColors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(auth, 'Faculty Suite'),
          _buildSectorSwitchSection(context, auth),
          ListTile(
            leading: const Icon(Icons.grade_outlined),
            title: const Text('Exam Scoring & Results'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherResultsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.how_to_reg_outlined),
            title: const Text('Admission Verification Queue'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherRequestsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Digital Study Materials'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentMaterialsScreen()));
            },
          ),
          const Divider(color: BeastColors.borderSubtle),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Campus Circulars'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: const Text('Faculty Platform Tour'),
            onTap: () {
              Navigator.pop(context);
              BeastTutorial.replay(context, 'TEACHER');
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADMIN & SUPER ADMIN PORTAL
  // ============================================================
  Widget _buildAdminPortal(AuthProvider auth) {
    final List<Widget> pages = [
      const AdminDashboardScreen(),
      const StudentManagementScreen(),
      const AdminBatchesScreen(),
      const AdminTimetableScreen(),
      const ProfileScreen(),
    ];

    const destinations = [
      NavDestinationItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics_rounded, label: 'Overview'),
      NavDestinationItem(icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, label: 'Students'),
      NavDestinationItem(icon: Icons.hub_outlined, selectedIcon: Icons.hub_rounded, label: 'Academics'),
      NavDestinationItem(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month_rounded, label: 'Timetable'),
      NavDestinationItem(icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts_rounded, label: 'Profile'),
    ];

    final isSuper = auth.isSuperAdmin;

    return ResponsiveScaffold(
      title: isSuper ? 'Executive Command' : 'Administration',
      selectedIndex: _currentIndex.clamp(0, pages.length - 1),
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: destinations,
      drawer: _buildAdminDrawer(context, auth),
      actions: _buildCommonActions(context, auth),
      body: IndexedStack(index: _currentIndex.clamp(0, pages.length - 1), children: pages),
    );
  }

  Widget _buildAdminDrawer(BuildContext context, AuthProvider auth) {
    final isSuper = auth.isSuperAdmin;

    return Drawer(
      backgroundColor: BeastColors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(auth, isSuper ? 'Institutional Executive' : 'Institutional Admin'),
          _buildSectorSwitchSection(context, auth),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Faculty Directory'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherManagementScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_ind_outlined),
            title: const Text('Admissions & Requests Queue'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsManagementScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Fee Ledger & Billing'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Audit Logs & Compliance'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAuditScreen()));
            },
          ),
          if (isSuper) ...[
            const Divider(color: BeastColors.borderSubtle),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined, color: BeastColors.danger),
              title: const Text('Administrator Directory', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManagementScreen()));
              },
            ),
          ],
          const Divider(color: BeastColors.borderSubtle),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Campus Circulars'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.explore_outlined),
            title: const Text('System Platform Tour'),
            onTap: () {
              Navigator.pop(context);
              BeastTutorial.replay(context, auth.role);
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON DRAWER & APPBAR UTILITIES & SECTOR SWITCHING
  // ============================================================
  Future<void> _handleSectorSwitch(BuildContext context, AuthProvider auth, String targetRole) async {
    if (auth.role == targetRole) return;
    final messenger = ScaffoldMessenger.of(context);
    final success = await auth.switchRole(targetRole);
    if (!mounted) return;
    if (success) {
      setState(() => _currentIndex = 0);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Switched to ${targetRole.replaceAll('_', ' ').toUpperCase()} sector'),
          backgroundColor: BeastColors.brandPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to switch sector'),
          backgroundColor: BeastColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSectorSwitchSection(BuildContext context, AuthProvider auth) {
    if (!auth.canSwitchRoles) return const SizedBox.shrink();

    final roles = auth.availableRoles;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BeastColors.brandPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(BeastRadius.md),
        border: Border.all(color: BeastColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, size: 16, color: BeastColors.brandPrimary),
              const SizedBox(width: 6),
              Text(
                'SWITCH SECTOR',
                style: BeastTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: BeastColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: roles.map((r) {
              final isCurrent = auth.role == r;
              String label = 'Student';
              IconData icon = Icons.school_rounded;
              if (r == 'teacher') {
                label = 'Faculty';
                icon = Icons.psychology_rounded;
              } else if (r == 'admin') {
                label = 'Admin';
                icon = Icons.admin_panel_settings_rounded;
              } else if (r == 'super_admin') {
                label = 'Executive';
                icon = Icons.security_rounded;
              }

              return ChoiceChip(
                selected: isCurrent,
                avatar: Icon(icon, size: 14, color: isCurrent ? BeastColors.white : BeastColors.textSecondary),
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? BeastColors.white : BeastColors.textPrimary,
                  ),
                ),
                selectedColor: BeastColors.brandPrimary,
                backgroundColor: BeastColors.white,
                onSelected: (selected) {
                  if (selected && !isCurrent) {
                    Navigator.pop(context);
                    _handleSectorSwitch(context, auth, r);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(AuthProvider auth, String roleTitle) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: BeastColors.surfaceWarm.withValues(alpha: 0.4),
        border: const Border(bottom: BorderSide(color: BeastColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BeastLogo(size: 40, borderRadius: BeastRadius.sm),
          const SizedBox(height: BeastSpacing.md),
          Text(
            auth.fullName.isNotEmpty ? auth.fullName : 'Academic User',
            style: BeastTypography.title.copyWith(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$roleTitle • ${auth.email}',
            style: BeastTypography.caption,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCommonActions(BuildContext context, AuthProvider auth) {
    return [
      if (auth.canSwitchRoles)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: PopupMenuButton<String>(
            tooltip: 'Switch Institutional Sector',
            onSelected: (targetRole) => _handleSectorSwitch(context, auth, targetRole),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: BeastColors.brandPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(BeastRadius.sm),
                border: Border.all(color: BeastColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 16, color: BeastColors.brandPrimary),
                  const SizedBox(width: 4),
                  Text(
                    auth.role == 'super_admin'
                        ? 'Executive'
                        : auth.role == 'teacher'
                            ? 'Faculty'
                            : auth.role == 'admin'
                                ? 'Admin'
                                : 'Student',
                    style: BeastTypography.caption.copyWith(fontWeight: FontWeight.w700, color: BeastColors.brandPrimary),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16, color: BeastColors.brandPrimary),
                ],
              ),
            ),
            itemBuilder: (context) {
              return auth.availableRoles.map((r) {
                final isCurrent = auth.role == r;
                String title = 'Student Workspace';
                IconData icon = Icons.school_rounded;
                if (r == 'teacher') {
                  title = 'Faculty Portal';
                  icon = Icons.psychology_rounded;
                } else if (r == 'admin') {
                  title = 'Administration';
                  icon = Icons.admin_panel_settings_rounded;
                } else if (r == 'super_admin') {
                  title = 'Executive Command';
                  icon = Icons.security_rounded;
                }

                return PopupMenuItem<String>(
                  value: r,
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: isCurrent ? BeastColors.brandPrimary : BeastColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                            color: isCurrent ? BeastColors.brandPrimary : BeastColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isCurrent)
                        const Icon(Icons.check_rounded, size: 16, color: BeastColors.brandPrimary),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ),
      IconButton(
        icon: const Icon(Icons.search_rounded),
        tooltip: 'Universal Search',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
      ),
      IconButton(
        icon: const Icon(Icons.notifications_outlined),
        tooltip: 'Notifications',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      ),
      IconButton(
        icon: const Icon(Icons.campaign_outlined),
        tooltip: 'Circulars & Notices',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
      ),
      IconButton(
        icon: const Icon(Icons.help_outline_rounded),
        tooltip: 'Role Guide',
        onPressed: () => BeastTutorial.replay(context, auth.role),
      ),
      const SizedBox(width: 8),
    ];
  }
}
