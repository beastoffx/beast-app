import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'student_activation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillCredentials(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed. Please check credentials.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.signInWithGoogle();

    if (!mounted) return;

    if (result == 'UNLINKED') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StudentActivationScreen()),
      );
    } else if (result == 'ERROR') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Google authentication failed.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRecoveryDialog() {
    final recoveryEmailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Recovery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your institutional email address to request password assistance.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: recoveryEmailController,
              decoration: const InputDecoration(
                labelText: 'Institutional Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = recoveryEmailController.text.trim();
              if (email.isNotEmpty) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                await auth.recoverPassword(email);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recovery request submitted to administration.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Academy Emblem & Header
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.school_rounded,
                        size: 40,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'B.E.A.S.T ACADEMY',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Unified Digital Campus & Academic Portal',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Card container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Sign In to Your Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Continue with Google Primary Button
                        OutlinedButton(
                          onPressed: auth.isLoading ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent,
                                ),
                                child: const Center(
                                  child: Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or with credentials',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Institutional Email',
                            hintText: 'name@beastacademy.edu',
                            prefixIcon: Icon(Icons.alternate_email, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your institutional email.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showRecoveryDialog,
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(fontSize: 13, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Submit Button
                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _handleLogin,
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Sign In'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick-Role Selector for Testing
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Demo / Quick Role Sign In:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.school, size: 16, color: AppColors.primary),
                            label: const Text('Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _fillCredentials('student1@beastacademy.edu', 'Student@123'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.person, size: 16, color: AppColors.primary),
                            label: const Text('Teacher', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _fillCredentials('physics.teacher@beastacademy.edu', 'Teacher@123'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.admin_panel_settings, size: 16, color: AppColors.primary),
                            label: const Text('Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _fillCredentials('admin@beastacademy.edu', 'Admin@123'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
