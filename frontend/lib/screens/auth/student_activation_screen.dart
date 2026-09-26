import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/beast_components.dart';
import '../../widgets/beast_logo.dart';

class StudentActivationScreen extends StatefulWidget {
  const StudentActivationScreen({super.key});

  @override
  State<StudentActivationScreen> createState() => _StudentActivationScreenState();
}

class _StudentActivationScreenState extends State<StudentActivationScreen> {
  // Step tracking: 1 = Google Verified prompt, 2 = Enter Student ID, 3 = Confirm Identity & Email, 4 = Enter Email OTP, 5 = Activated
  int _currentStep = 1;

  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  Map<String, dynamic>? _studentData;
  String? _sessionId;
  int _resendCountdown = 60;
  Timer? _resendTimer;
  bool _canResend = false;

  @override
  void dispose() {
    _studentIdController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  // Action 1: Validate Student ID
  Future<void> _handleValidateStudentId() async {
    final studentId = _studentIdController.text.trim();
    if (studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your official Student ID (e.g. BST-2027-00001)')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final data = await auth.validateStudentId(studentId);

    if (data != null && mounted) {
      setState(() {
        _studentData = data;
        _currentStep = 3;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Invalid Student ID.'),
          backgroundColor: BeastColors.error,
        ),
      );
    }
  }

  // Action 2: Request Email OTP
  Future<void> _handleRequestOtp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final res = await auth.sendActivationOtp(_studentIdController.text.trim());

    if (res != null && mounted) {
      setState(() {
        _sessionId = res['sessionId'];
        if (res['emailMasked'] != null && _studentData != null) {
          _studentData!['emailMasked'] = res['emailMasked'];
        }
        _currentStep = 4;
      });
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent to your registered institute email.'),
          backgroundColor: BeastColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to send OTP.'),
          backgroundColor: BeastColors.error,
        ),
      );
    }
  }

  // Action 3: Verify OTP & Activate Account
  Future<void> _handleVerifyAndActivate() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit OTP.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.verifyActivationOtp(
      sessionId: _sessionId!,
      otp: otp,
      studentIdNumber: _studentIdController.text.trim(),
    );

    if (ok && mounted) {
      setState(() => _currentStep = 5);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Verification failed. Please check the code.'),
          backgroundColor: BeastColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final googleName = auth.pendingGoogleName ?? 'Student';
    final googleEmail = auth.pendingGoogleEmail ?? '';

    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text('Institute Account Activation', style: BeastTypography.h3),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: BeastCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(child: BeastLogo(size: 48)),
                  const SizedBox(height: 16),

                  // Progress Header
                  _buildProgressIndicator(),
                  const SizedBox(height: 24),

                  // STEP 1: Google Verified Message
                  if (_currentStep == 1) ...[
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: BeastColors.peach200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user, color: BeastColors.dark900, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome, $googleName',
                      style: BeastTypography.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      googleEmail,
                      style: BeastTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: BeastColors.peach100,
                        borderRadius: BorderRadius.circular(BeastRadius.sm),
                        border: Border.all(color: BeastColors.peach300),
                      ),
                      child: Text(
                        'Your Google account is authenticated, but it is not yet linked to a B.E.A.S.T Academy institutional account.',
                        style: BeastTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BeastColors.dark900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.school, color: Colors.white),
                      label: const Text('Activate Institute Account', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => _currentStep = 2),
                    ),
                  ],

                  // STEP 2: Enter Student ID
                  if (_currentStep == 2) ...[
                    Text(
                      'Enter Institute Student ID',
                      style: BeastTypography.h3,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the official Student ID issued to you by B.E.A.S.T Academy administration.',
                      style: BeastTypography.caption,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _studentIdController,
                      decoration: const InputDecoration(
                        labelText: 'Student ID Number',
                        hintText: 'e.g. BST-2027-00001',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BeastColors.dark900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: auth.isLoading ? null : _handleValidateStudentId,
                      child: auth.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Find Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],

                  // STEP 3: Confirm Profile
                  if (_currentStep == 3 && _studentData != null) ...[
                    Text('Confirm Your Profile', style: BeastTypography.h3),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: BeastColors.neutral100,
                        borderRadius: BorderRadius.circular(BeastRadius.sm),
                        border: Border.all(color: BeastColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: ${_studentData!['name']}', style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                          Text('ID: ${_studentData!['studentIdNumber']}', style: BeastTypography.caption),
                          Text('Class: ${_studentData!['className'] ?? "N/A"}', style: BeastTypography.caption),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BeastColors.dark900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: auth.isLoading ? null : _handleRequestOtp,
                      child: auth.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],

                  // STEP 4: Enter OTP
                  if (_currentStep == 4) ...[
                    Text('Enter Verification Code', style: BeastTypography.h3),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the 6-digit verification code sent to your registered email.',
                      style: BeastTypography.caption,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _canResend ? 'Did not receive code?' : 'Resend in ${_resendCountdown}s',
                          style: BeastTypography.caption,
                        ),
                        TextButton(
                          onPressed: _canResend ? _handleRequestOtp : null,
                          child: const Text('Resend Code'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BeastColors.dark900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: auth.isLoading ? null : _handleVerifyAndActivate,
                      child: auth.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Verify & Activate Account', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],

                  // STEP 5: Account Activated Success
                  if (_currentStep == 5) ...[
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: BeastColors.successLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: BeastColors.success, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Account Activated!',
                      style: BeastTypography.h2.copyWith(color: BeastColors.success),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Google account is now securely linked to your institutional Student profile.',
                      style: BeastTypography.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BeastColors.dark900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text('Continue to Student Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepDot(1, 'Google'),
        _buildStepLine(1),
        _buildStepDot(2, 'ID'),
        _buildStepLine(2),
        _buildStepDot(3, 'Email'),
        _buildStepLine(3),
        _buildStepDot(4, 'OTP'),
        _buildStepLine(4),
        _buildStepDot(5, 'Done'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isDone = _currentStep > step;
    final isCurrent = _currentStep == step;

    Color color = BeastColors.neutral300;
    if (isDone) color = BeastColors.success;
    if (isCurrent) color = BeastColors.dark900;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isDone
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$step',
                  style: TextStyle(
                    color: isCurrent ? Colors.white : BeastColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? BeastColors.dark900 : BeastColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isDone = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        color: isDone ? BeastColors.success : BeastColors.neutral200,
      ),
    );
  }
}
