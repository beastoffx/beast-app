import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:beast_academy/core/theme/app_theme.dart';
import 'package:beast_academy/providers/auth_provider.dart';
import 'package:beast_academy/providers/student_provider.dart';
import 'package:beast_academy/providers/teacher_provider.dart';
import 'package:beast_academy/providers/admin_provider.dart';
import 'package:beast_academy/screens/main_portal_screen.dart';

void main() {
  testWidgets('B.E.A.S.T ACADEMY app bootstrap and Login Screen render test', (WidgetTester tester) async {
    final authProvider = AuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<StudentProvider>(create: (_) => StudentProvider()),
          ChangeNotifierProvider<TeacherProvider>(create: (_) => TeacherProvider()),
          ChangeNotifierProvider<AdminProvider>(create: (_) => AdminProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainPortalScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify Academy branding is rendered
    expect(find.text('B.E.A.S.T ACADEMY'), findsOneWidget);
    expect(find.text('Sign In to Your Account'), findsOneWidget);
    expect(find.text('Institutional Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify Role quick selector chips exist for demo/testing
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });
}
