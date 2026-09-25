import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/responsive_layout.dart';
import 'auth/login_screen.dart';
import 'student/student_home_screen.dart';
import 'student/student_timetable_screen.dart';
import 'student/student_materials_screen.dart';
import 'student/student_doubts_screen.dart';
import 'teacher/teacher_home_screen.dart';
import 'teacher/teacher_attendance_screen.dart';
import 'teacher/teacher_assignments_screen.dart';
import 'teacher/teacher_doubts_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_batches_screen.dart';
import 'admin/admin_timetable_screen.dart';
import 'admin/admin_fees_screen.dart';
import 'common/profile_screen.dart';
import 'common/notices_screen.dart';
import 'common/search_screen.dart';

class MainPortalScreen extends StatefulWidget {
  const MainPortalScreen({super.key});

  @override
  State<MainPortalScreen> createState() => _MainPortalScreenState();
}

class _MainPortalScreenState extends State<MainPortalScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (auth.isStudent) {
      return _buildStudentPortal();
    } else if (auth.isTeacher) {
      return _buildTeacherPortal();
    } else {
      return _buildAdminPortal();
    }
  }

  Widget _buildStudentPortal() {
    final List<Widget> pages = [
      const StudentHomeScreen(),
      const StudentTimetableScreen(),
      const StudentMaterialsScreen(),
      const StudentDoubtsScreen(),
      const ProfileScreen(),
    ];

    const destinations = [
      NavDestinationItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
      NavDestinationItem(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month, label: 'Classes'),
      NavDestinationItem(icon: Icons.menu_book_outlined, selectedIcon: Icons.menu_book, label: 'Materials'),
      NavDestinationItem(icon: Icons.help_outline, selectedIcon: Icons.help, label: 'Doubts'),
      NavDestinationItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
    ];

    return ResponsiveScaffold(
      title: 'Student Campus',
      selectedIndex: _currentIndex.clamp(0, pages.length - 1),
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: destinations,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search Academy',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.campaign_outlined),
          tooltip: 'Notices',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
        ),
      ],
      body: IndexedStack(index: _currentIndex.clamp(0, pages.length - 1), children: pages),
    );
  }

  Widget _buildTeacherPortal() {
    final List<Widget> pages = [
      const TeacherHomeScreen(),
      const TeacherAttendanceScreen(),
      const TeacherAssignmentsScreen(),
      const TeacherDoubtsScreen(),
      const ProfileScreen(),
    ];

    const destinations = [
      NavDestinationItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Home'),
      NavDestinationItem(icon: Icons.how_to_reg_outlined, selectedIcon: Icons.how_to_reg, label: 'Attendance'),
      NavDestinationItem(icon: Icons.assignment_outlined, selectedIcon: Icons.assignment, label: 'Work'),
      NavDestinationItem(icon: Icons.question_answer_outlined, selectedIcon: Icons.question_answer, label: 'Doubts'),
      NavDestinationItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
    ];

    return ResponsiveScaffold(
      title: 'Faculty Workspace',
      selectedIndex: _currentIndex.clamp(0, pages.length - 1),
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: destinations,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search Academy',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.campaign_outlined),
          tooltip: 'Notices',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
        ),
      ],
      body: IndexedStack(index: _currentIndex.clamp(0, pages.length - 1), children: pages),
    );
  }

  Widget _buildAdminPortal() {
    final List<Widget> pages = [
      const AdminDashboardScreen(),
      const AdminBatchesScreen(),
      const AdminTimetableScreen(),
      const AdminFeesScreen(),
      const ProfileScreen(),
    ];

    const destinations = [
      NavDestinationItem(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics, label: 'Control'),
      NavDestinationItem(icon: Icons.hub_outlined, selectedIcon: Icons.hub, label: 'Academics'),
      NavDestinationItem(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month, label: 'Schedule'),
      NavDestinationItem(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet, label: 'Finance'),
      NavDestinationItem(icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts, label: 'Settings'),
    ];

    return ResponsiveScaffold(
      title: 'Institutional Suite',
      selectedIndex: _currentIndex.clamp(0, pages.length - 1),
      onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
      destinations: destinations,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search Academy',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.campaign_outlined),
          tooltip: 'Notices',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
        ),
      ],
      body: IndexedStack(index: _currentIndex.clamp(0, pages.length - 1), children: pages),
    );
  }
}
