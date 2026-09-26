import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_card.dart';

class StudentActivationScreen extends StatefulWidget {
  const StudentActivationScreen({super.key});

  @override
  State<StudentActivationScreen> createState() => _StudentActivationScreenState();
}

class _StudentActivationScreenState extends State<StudentActivationScreen> {
  // Step tracking: 1 = Google Verified prompt, 2 = Enter Student ID, 3 = Confirm Identity & Enter Phone, 4 = Enter OTP, 5 = Activated
  int _currentStep = 1;

  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  Map<String, dynamic>? _studentData;
  String? _sessionId;
  int _resendCountdown = 60;
  Timer? _resendTimer;
  bool _canResend = false;

  @override
  void dispose() {
    _studentIdController.dispose();
    _phoneController.dispose();
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
        if (data['registeredPhone'] != null) {
          _phoneController.text = data['registeredPhone'];
        }
        _currentStep = 3;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Invalid Student ID.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Action 2: Request OTP
  Future<void> _handleRequestOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number for OTP.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sid = await auth.sendActivationOtp(_studentIdController.text.trim(), phone);

    if (sid != null && mounted) {
      setState(() {
        _sessionId = sid;
        _currentStep = 4;
      });
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code dispatched to mobile phone.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to send verification code.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Action 3: Verify OTP and Activate
  Future<void> _handleVerifyAndActivate() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit verification code.')),
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
          backgroundColor: AppColors.error,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Institute Account Activation'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress Header
                  _buildProgressIndicator(),
                  const SizedBox(height: 24),

                  // STEP 1: Google Verified Message
                  if (_currentStep == 1) ...[
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.verified_user, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome, $googleName',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      googleEmail,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Text(
                        'Your Google account is authenticated, but it is not yet linked to a B.E.A.S.T Academy institutional account.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.school, color: Colors.white),
                      label: const Text('Activate Institute Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => _currentStep = 2),
                    ),
                  ],

                  // STEP 2: Enter Student ID
                  if (_currentStep == 2) ...[
                    const Text(
                      'Enter Institute Student ID',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter the official Student ID issued to you by B.E.A.S.T Academy administration.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _studentIdController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Official Student ID',
                        hintText: 'e.g. BST-2027-00001',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: auth.isLoading ? null : _handleValidateStudentId,
                      child: auth.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Verify Student ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],

                  // STEP 3: Confirm Identity & Enter Phone
                  if (_currentStep == 3 && _studentData != null) ...[
                    const Text(
                      'Confirm Identity & Phone',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Student Name:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              Text(_studentData!['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Student ID:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              Text(_studentData!['studentIdNumber'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Enrolled Batch:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              Text('${_studentData!['className']} (${_studentData!['batchName']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (_studentData!['phoneMasked'] != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Registered Phone:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                Text(_studentData!['phoneMasked'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Phone for Verification',
                        hintText: '+91 98765 11111',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: auth.isLoading ? null : _handleRequestOtp,
                      child: auth.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Send Verification OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],

                  // STEP 4: Enter OTP
                  if (_currentStep == 4) ...[
                    const Text(
                      'Enter Verification Code',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A 6-digit verification code has been dispatched to ${_phoneController.text.trim()}.',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
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
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: auth.isLoading ? null : _handleVerifyAndActivate,
                      child: auth.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Verify & Activate Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],

                  // STEP 5: Account Activated Success
                  if (_currentStep == 5) ...[
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.check, color: Colors.white, size: 44),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Account Activated!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Google account is now securely linked to your institutional Student profile.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        // Return to root, AuthProvider isAuthenticated will trigger StudentDashboard
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text('Continue to Student Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        _buildStepDot(3, 'Phone'),
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

    Color color = Colors.grey.shade300;
    if (isDone) color = Colors.green;
    if (isCurrent) color = AppColors.primary;

    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color,
          child: isDone
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : Text('$step', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? AppColors.primary : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isDone = _currentStep > afterStep;
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 14, left: 2, right: 2),
      color: isDone ? Colors.green : Colors.grey.shade300,
    );
  }
}
