import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/beast_components.dart';
import '../../widgets/beast_logo.dart';
import '../../widgets/google_logo.dart';
import 'onboarding_request_screen.dart';
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Invalid email or password. Please verify your credentials.'),
          backgroundColor: BeastColors.danger,
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
      _showUnlinkedOptionsDialog(
        auth.pendingGoogleEmail,
        auth.pendingGoogleName,
        auth.pendingGoogleUid,
      );
    } else if (result == 'ERROR') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Google authentication was not completed.'),
          backgroundColor: BeastColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showUnlinkedOptionsDialog(String? email, String? name, String? googleUid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.md)),
        backgroundColor: BeastColors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: BeastColors.peach200,
                borderRadius: BorderRadius.circular(BeastRadius.xs),
              ),
              child: const Icon(Icons.account_circle_outlined, size: 22, color: BeastColors.dark900),
            ),
            const SizedBox(width: BeastSpacing.md),
            const Expanded(
              child: Text(
                'Account Not Registered',
                style: BeastTypography.title,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The Google account ($email) is not yet linked to an active institutional profile.',
              style: BeastTypography.body.copyWith(color: BeastColors.textSecondary),
            ),
            const SizedBox(height: BeastSpacing.md),
            Text(
              'Select an activation pathway:',
              style: BeastTypography.label,
            ),
            const SizedBox(height: BeastSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Activate with Student ID & OTP'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BeastColors.textPrimary,
                side: const BorderSide(color: BeastColors.borderStrong),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.sm)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentActivationScreen()),
                );
              },
            ),
            const SizedBox(height: BeastSpacing.sm),
            ElevatedButton.icon(
              icon: const Icon(Icons.app_registration_rounded, size: 18),
              label: const Text('Submit Admission Application'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BeastColors.brandPrimary,
                foregroundColor: BeastColors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.sm)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OnboardingRequestScreen(
                      initialEmail: email,
                      initialName: name,
                      initialGoogleUid: googleUid,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: BeastColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _showRecoveryDialog() {
    final recoveryEmailController = TextEditingController(text: _emailController.text);
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.md)),
          backgroundColor: BeastColors.white,
          title: const Text('Account Recovery Assistance', style: BeastTypography.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your registered institutional email to request password assistance from the administration desk.',
                style: BeastTypography.body.copyWith(color: BeastColors.textSecondary),
              ),
              const SizedBox(height: BeastSpacing.lg),
              TextField(
                controller: recoveryEmailController,
                decoration: const InputDecoration(
                  labelText: 'Institutional Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: BeastColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final email = recoveryEmailController.text.trim();
                      if (email.isNotEmpty) {
                        setDialogState(() => isSubmitting = true);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        await auth.recoverPassword(email);
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recovery request submitted to administration.'),
                              backgroundColor: BeastColors.success,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: BeastColors.brandPrimary,
                foregroundColor: BeastColors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      body: isDesktop ? _buildDesktopLayout(auth) : _buildMobileLayout(auth),
    );
  }

  Widget _buildDesktopLayout(AuthProvider auth) {
    return Row(
      children: [
        // Left Column: Institutional Brand Showcase
        Expanded(
          flex: 5,
          child: Container(
            color: BeastColors.surfaceWarm.withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BeastLogo(
                  size: 72,
                  showWordmark: true,
                  showSubtitle: true,
                ),
                const SizedBox(height: BeastSpacing.xxxl),
                Text(
                  'Empowering Academic\nExcellence & Discipline',
                  style: BeastTypography.display.copyWith(fontSize: 36, height: 1.2),
                ),
                const SizedBox(height: BeastSpacing.md),
                Text(
                  'Access your institutional timetable, real-time attendance registers, coursework evaluations, and direct faculty academic support.',
                  style: BeastTypography.body.copyWith(
                    color: BeastColors.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: BeastSpacing.xxxl),
                // Trust badges
                Row(
                  children: [
                    _buildTrustBadge(Icons.security_rounded, 'Role-Based Access'),
                    const SizedBox(width: BeastSpacing.lg),
                    _buildTrustBadge(Icons.bolt_rounded, 'Real-Time Sync'),
                    const SizedBox(width: BeastSpacing.lg),
                    _buildTrustBadge(Icons.cloud_done_rounded, 'Cloud Verified'),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Right Column: Focused Auth Card
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildAuthCard(auth),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BeastColors.white,
        borderRadius: BorderRadius.circular(BeastRadius.sm),
        border: Border.all(color: BeastColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: BeastColors.dark900),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BeastColors.dark900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(AuthProvider auth) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: BeastLogo(
                  size: 64,
                  showWordmark: true,
                  showSubtitle: true,
                ),
              ),
              const SizedBox(height: BeastSpacing.xxl),
              _buildAuthCard(auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard(AuthProvider auth) {
    return BeastCard(
      padding: const EdgeInsets.all(BeastSpacing.xxl),
      borderRadius: BeastRadius.lg,
      boxShadow: BeastShadows.card,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sign In to Your Account', style: BeastTypography.headline),
            const SizedBox(height: 4),
            Text(
              'Sign in to your official B.E.A.S.T ACADEMY portal.',
              style: BeastTypography.caption.copyWith(color: BeastColors.textSecondary),
            ),
            const SizedBox(height: BeastSpacing.xl),

            // Authentic Google Login Button
            OutlinedButton(
              onPressed: auth.isLoading ? null : _handleGoogleSignIn,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: BeastColors.borderStrong),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.sm)),
                backgroundColor: BeastColors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogo(size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: BeastColors.dark900,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BeastSpacing.lg),

            // Divider
            Row(
              children: [
                const Expanded(child: Divider(color: BeastColors.borderSubtle)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.md),
                  child: Text(
                    'or institutional credentials',
                    style: BeastTypography.caption,
                  ),
                ),
                const Expanded(child: Divider(color: BeastColors.borderSubtle)),
              ],
            ),
            const SizedBox(height: BeastSpacing.lg),

            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Institutional Email',
                hintText: 'student@beastacademy.edu',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your institutional email';
                if (!v.contains('@')) return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: BeastSpacing.md),

            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: BeastColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your password';
                return null;
              },
            ),
            const SizedBox(height: BeastSpacing.sm),

            // Forgot password link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showRecoveryDialog,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: BeastColors.textSecondary,
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: BeastSpacing.sm),

            // Submit Button
            BeastPrimaryButton(
              label: 'Sign In to Portal',
              icon: Icons.login_rounded,
              isLoading: auth.isLoading,
              onPressed: _handleLogin,
            ),
            const SizedBox(height: BeastSpacing.xl),

            // Secondary Pathways
            const Divider(color: BeastColors.borderSubtle),
            const SizedBox(height: BeastSpacing.sm),

            Center(
              child: Text(
                'New Applicant or Pre-Enrolled Student?',
                style: BeastTypography.caption.copyWith(color: BeastColors.textSecondary),
              ),
            ),
            const SizedBox(height: BeastSpacing.xs),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.app_registration_rounded, size: 16),
                    label: const Text('Apply / Track'),
                    style: TextButton.styleFrom(
                      foregroundColor: BeastColors.dark900,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OnboardingRequestScreen()),
                      );
                    },
                  ),
                ),
                Container(height: 16, width: 1, color: BeastColors.borderSubtle),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.verified_user_outlined, size: 16),
                    label: const Text('Activate ID'),
                    style: TextButton.styleFrom(
                      foregroundColor: BeastColors.dark900,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StudentActivationScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
