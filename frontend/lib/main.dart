import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/student_provider.dart';
import 'providers/teacher_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/main_portal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.initAuth();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<StudentProvider>(create: (_) => StudentProvider()),
        ChangeNotifierProvider<TeacherProvider>(create: (_) => TeacherProvider()),
        ChangeNotifierProvider<AdminProvider>(create: (_) => AdminProvider()),
      ],
      child: const BeastAcademyApp(),
    ),
  );
}

class BeastAcademyApp extends StatelessWidget {
  const BeastAcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B.E.A.S.T ACADEMY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontFamilyFallback: ['SpaceGrotesk', 'sans-serif'],
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MainPortalScreen(),
    );
  }
}
