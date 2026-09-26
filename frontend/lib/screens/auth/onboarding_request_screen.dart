import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/theme/beast_tokens.dart';
import '../../widgets/beast_components.dart';
import '../../widgets/beast_logo.dart';

class OnboardingRequestScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialName;
  final String? initialGoogleUid;

  const OnboardingRequestScreen({
    super.key,
    this.initialEmail,
    this.initialName,
    this.initialGoogleUid,
  });

  @override
  State<OnboardingRequestScreen> createState() => _OnboardingRequestScreenState();
}

class _OnboardingRequestScreenState extends State<OnboardingRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form State
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedRole = 'student';
  String? _selectedClassId;
  String? _selectedBatchId;
  String? _selectedSessionId;

  List<dynamic> _classes = [];
  List<dynamic> _batches = [];
  Map<String, dynamic>? _currentSession;
  bool _isLoadingMeta = true;
  bool _isSubmitting = false;

  // Status Tracking State
  final TextEditingController _trackingEmailController = TextEditingController();
  Map<String, dynamic>? _trackedRequest;
  List<dynamic> _trackedRequests = [];
  bool _isTracking = false;
  String? _trackingError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _trackingEmailController.text = widget.initialEmail ?? '';

    _loadMetadata();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _trackStatus(widget.initialEmail!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _qualificationController.dispose();
    _departmentController.dispose();
    _notesController.dispose();
    _trackingEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    setState(() => _isLoadingMeta = true);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/requests/meta');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        setState(() {
          _classes = data['classes'] ?? [];
          _batches = data['batches'] ?? [];
          _currentSession = data['currentSession'];
          _selectedSessionId = _currentSession?['id'];
          if (_classes.isNotEmpty) {
            _selectedClassId = _classes.first['id'];
          }
          _updateFilteredBatches();
        });
      }
    } catch (_) {
      // Fallback defaults if offline
    } finally {
      if (mounted) setState(() => _isLoadingMeta = false);
    }
  }

  void _updateFilteredBatches() {
    final available = _batches.where((b) => b['class_id'] == _selectedClassId).toList();
    if (available.isNotEmpty) {
      _selectedBatchId = available.first['id'];
    } else {
      _selectedBatchId = null;
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == 'student' && (_selectedClassId == null || _selectedBatchId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target class and batch.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final body = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'google_uid': widget.initialGoogleUid,
        'requested_role': _selectedRole,
        'target_class_id': _selectedRole == 'student' ? _selectedClassId : null,
        'target_batch_id': _selectedRole == 'student' ? _selectedBatchId : null,
        'target_session_id': _selectedRole == 'student' ? _selectedSessionId : null,
        'qualification': _selectedRole == 'teacher' ? _qualificationController.text.trim() : null,
        'department': _selectedRole != 'student' ? _departmentController.text.trim() : null,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      final url = Uri.parse('${ApiConstants.baseUrl}/api/requests');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);

      if (res.statusCode == 201) {
        if (!mounted) return;
        _showSuccessDialog(data['data']);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Application submission failed.'),
            backgroundColor: BeastColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e'), backgroundColor: BeastColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _trackStatus(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;

    setState(() {
      _isTracking = true;
      _trackingError = null;
    });

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/requests/status?email=${Uri.encodeComponent(cleanEmail)}');
      final res = await http.get(url).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded['requests'] ??
            (decoded['data'] != null && decoded['data']['requests'] != null
                ? decoded['data']['requests']
                : (decoded['data'] != null ? [decoded['data']] : []));
        final reqList = list is List ? list : [];
        setState(() {
          _trackedRequests = reqList;
          _trackedRequest = decoded['data'];
          if (reqList.isEmpty) {
            _trackingError = 'No application found for this email address.';
          }
        });
      } else {
        setState(() => _trackingError = 'Failed to fetch application status.');
      }
    } catch (e) {
      setState(() => _trackingError = 'Network error fetching status: $e');
    } finally {
      if (mounted) setState(() => _isTracking = false);
    }
  }

  Future<void> _resendApplication(String id, String email) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/requests/$id/resend');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Application resent successfully.'),
            backgroundColor: BeastColors.success,
          ),
        );
        _trackStatus(email);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to resend application.'),
            backgroundColor: BeastColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: BeastColors.error),
      );
    }
  }

  Future<void> _confirmDeleteApplication(String id, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Application'),
        content: const Text(
          'Are you sure you want to completely withdraw and delete this application from B.E.A.S.T Academy? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BeastColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/requests/$id?email=${Uri.encodeComponent(email)}');
      final res = await http.delete(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email}));
      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Application removed totally from the app.'),
            backgroundColor: BeastColors.success,
          ),
        );
        _trackStatus(email);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to delete application.'),
            backgroundColor: BeastColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: BeastColors.error),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> requestData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: BeastColors.success, size: 28),
            SizedBox(width: 8),
            Text('Application Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your institutional application has been successfully submitted to B.E.A.S.T. Academy.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BeastColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Application ID: ${requestData['id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Role: ${requestData['requested_role'].toString().toUpperCase()}',
                      style: const TextStyle(fontSize: 12, color: BeastColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Initial Status: ${requestData['status']}',
                      style: const TextStyle(fontSize: 12, color: BeastColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Approval Matrix Workflow:\n1. Faculty Academic Review\n2. Administration Clearance\n3. Super Admin Final Activation & Student ID Issuance',
              style: TextStyle(fontSize: 12, color: BeastColors.textMuted, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tabController.animateTo(1);
              _trackStatus(_emailController.text.trim());
            },
            child: const Text('Track Application'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text('Institutional Onboarding', style: BeastTypography.h3),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: BeastColors.dark900,
          unselectedLabelColor: BeastColors.textSecondary,
          indicatorColor: BeastColors.peach400,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.app_registration), text: 'New Application'),
            Tab(icon: Icon(Icons.timeline), text: 'Track Status'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplicationTab(),
          _buildTrackingTab(),
        ],
      ),
    );
  }

  Widget _buildApplicationTab() {
    if (_isLoadingMeta) {
      return const Center(child: BeastLoadingState(message: 'Loading academic options...'));
    }

    final availableBatches = _batches.where((b) => b['class_id'] == _selectedClassId).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(BeastSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BeastCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const BeastLogo(size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'B.E.A.S.T ACADEMY',
                              style: BeastTypography.h3,
                            ),
                            Text(
                              'Institutional Admission Application',
                              style: BeastTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: BeastColors.borderSubtle),
                  Text(
                    'Submit your institutional application for faculty and administration review.',
                    style: BeastTypography.caption,
                  ),
                  const SizedBox(height: 20),

                  // Requested Role Selector
                  Text('Applying For Role:', style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'student', label: Text('Student'), icon: Icon(Icons.school, size: 16)),
                      ButtonSegment(value: 'teacher', label: Text('Faculty'), icon: Icon(Icons.person, size: 16)),
                      ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings, size: 16)),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (set) => setState(() => _selectedRole = set.first),
                  ),
                  const SizedBox(height: 16),

                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Institutional Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Role-specific fields
                  if (_selectedRole == 'student') ...[
                    const Divider(height: 24),
                    const Text('Academic Enrollment Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),

                    // Class Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedClassId,
                      decoration: const InputDecoration(
                        labelText: 'Target Class *',
                        prefixIcon: Icon(Icons.class_outlined),
                      ),
                      items: _classes.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['id'].toString(),
                          child: Text('${c['name']} (${c['stream'] ?? ''})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedClassId = val;
                          _updateFilteredBatches();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Batch Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedBatchId,
                      decoration: const InputDecoration(
                        labelText: 'Target Batch *',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      items: availableBatches.map((b) {
                        return DropdownMenuItem<String>(
                          value: b['id'].toString(),
                          child: Text(b['name'].toString()),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedBatchId = val),
                    ),
                  ],

                  if (_selectedRole == 'teacher') ...[
                    const Divider(height: 24),
                    const Text('Faculty Qualifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _qualificationController,
                      decoration: const InputDecoration(
                        labelText: 'Highest Qualification (e.g. M.Sc. Physics)',
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department / Subject (e.g. Physics, Chemistry)',
                        prefixIcon: Icon(Icons.book_outlined),
                      ),
                    ),
                  ],

                  if (_selectedRole == 'admin') ...[
                    const Divider(height: 24),
                    const Text('Administrative Department', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department (e.g. Academic Operations, Admissions)',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes or Prior Academic History',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),

                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: BeastColors.primary,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit Institutional Application',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeastCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check Application Status',
                      style: BeastTypography.h3,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your application email address to view live review progress.',
                      style: BeastTypography.caption,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _trackingEmailController,
                            decoration: const InputDecoration(
                              labelText: 'Application Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BeastColors.dark900,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                          onPressed: _isTracking ? null : () => _trackStatus(_trackingEmailController.text),
                          child: _isTracking
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Track'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_trackingError != null)
                BeastCard(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: BeastColors.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_trackingError!, style: const TextStyle(color: BeastColors.error, fontSize: 13))),
                    ],
                  ),
                ),

              if (_trackedRequests.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Applications (${_trackedRequests.length})',
                      style: BeastTypography.h3.copyWith(fontSize: 16),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Apply for Another Sector'),
                      onPressed: () {
                        setState(() {
                          _nameController.text = _trackedRequests.first['name'] ?? _nameController.text;
                          _emailController.text = _trackingEmailController.text;
                          _tabController.animateTo(0);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final req in _trackedRequests) ...[
                  _buildTimelineCard(Map<String, dynamic>.from(req)),
                  const SizedBox(height: 12),
                ],
              ] else if (_trackedRequest != null)
                _buildTimelineCard(_trackedRequest!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> req) {
    final id = req['id']?.toString() ?? '';
    final status = req['status'] as String? ?? 'UNKNOWN';
    final role = req['requested_role'] as String? ?? 'student';
    final studentId = req['generated_student_id'] as String?;
    final rejectionReason = req['rejection_reason'] as String?;

    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Application #${req['id'].toString().substring(0, 12)}...',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const Divider(height: 20),

          Text('Applicant: ${req['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('Email: ${req['email']}', style: const TextStyle(fontSize: 12, color: BeastColors.textSecondary)),
          Text('Target Role: ${role.toUpperCase()}', style: const TextStyle(fontSize: 12, color: BeastColors.textSecondary)),
          if (req['class_name'] != null)
            Text('Class: ${req['class_name']} • Batch: ${req['batch_name'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: BeastColors.textSecondary)),

          const SizedBox(height: 20),
          const Text('Verification Workflow Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),

          // Timeline steps
          _buildTimelineStep(
            title: '1. Application Submitted',
            subtitle: 'Received into admissions queue',
            isDone: true,
            isCurrent: false,
          ),
          if (role == 'student')
            _buildTimelineStep(
              title: '2. Faculty Academic Review',
              subtitle: status == 'PENDING_TEACHER_REVIEW'
                  ? 'In review by Department Faculty'
                  : (status == 'REJECTED' && req['teacher_reviewed_at'] != null ? 'Rejected' : 'Approved by Faculty'),
              isDone: status != 'PENDING_TEACHER_REVIEW',
              isCurrent: status == 'PENDING_TEACHER_REVIEW',
              isRejected: status == 'REJECTED' && req['teacher_reviewed_at'] != null,
            ),
          if (role == 'student' || role == 'teacher')
            _buildTimelineStep(
              title: role == 'student' ? '3. Institutional Admin Clearance' : '2. Admin & Super Admin Review',
              subtitle: status == 'PENDING_ADMIN_REVIEW'
                  ? (role == 'teacher' ? 'In review by Admin & Super Admin' : 'In review by Academy Administrator')
                  : (status == 'REJECTED' && req['admin_reviewed_at'] != null ? 'Rejected' : 'Approved by Admin'),
              isDone: ['PENDING_SUPER_ADMIN_REVIEW', 'APPROVED'].contains(status),
              isCurrent: status == 'PENDING_ADMIN_REVIEW',
              isRejected: status == 'REJECTED' && req['admin_reviewed_at'] != null,
            ),
          _buildTimelineStep(
            title: role == 'admin' ? '2. Super Admin Review & Activation' : 'Final Super Admin Executive Activation',
            subtitle: status == 'APPROVED'
                ? (studentId != null ? 'Activated! Student ID: $studentId' : 'Account Activated')
                : (status == 'PENDING_SUPER_ADMIN_REVIEW' ? 'Pending Super Admin authorization' : 'Awaiting clearance'),
            isDone: status == 'APPROVED',
            isCurrent: status == 'PENDING_SUPER_ADMIN_REVIEW',
            isRejected: status == 'REJECTED' && req['super_admin_reviewed_at'] != null,
          ),

          if (status == 'REJECTED' && rejectionReason != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BeastColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rejection Reason:', style: TextStyle(fontWeight: FontWeight.bold, color: BeastColors.error, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(rejectionReason, style: const TextStyle(color: BeastColors.error, fontSize: 13)),
                ],
              ),
            ),
          ],

          if (status == 'APPROVED') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BeastColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: BeastColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account is active! You can now sign in using your Google account or credentials.',
                      style: const TextStyle(color: BeastColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions: Delete / Withdraw & Resend (with 24h rate limit)
          const SizedBox(height: 16),
          const Divider(height: 1, color: BeastColors.borderSubtle),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _confirmDeleteApplication(id, req['email'] ?? ''),
                icon: const Icon(Icons.delete_outline, size: 16, color: BeastColors.error),
                label: const Text('Delete Application', style: TextStyle(color: BeastColors.error, fontSize: 12)),
              ),
              if (status != 'APPROVED') ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _resendApplication(id, req['email'] ?? ''),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BeastColors.dark900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Resend Application', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isCurrent,
    bool isRejected = false,
  }) {
    Color iconColor = BeastColors.textMuted;
    IconData icon = Icons.circle_outlined;

    if (isRejected) {
      iconColor = BeastColors.error;
      icon = Icons.cancel;
    } else if (isDone) {
      iconColor = BeastColors.success;
      icon = Icons.check_circle;
    } else if (isCurrent) {
      iconColor = BeastColors.primary;
      icon = Icons.pending;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: BeastColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = BeastColors.primary;
    String label = status;

    switch (status) {
      case 'PENDING_TEACHER_REVIEW':
        color = Colors.amber.shade800;
        label = 'Faculty Review';
        break;
      case 'PENDING_ADMIN_REVIEW':
        color = Colors.blue;
        label = 'Admin Review';
        break;
      case 'PENDING_SUPER_ADMIN_REVIEW':
        color = Colors.purple;
        label = 'Super Admin Review';
        break;
      case 'APPROVED':
        color = BeastColors.success;
        label = 'Approved';
        break;
      case 'REJECTED':
        color = BeastColors.error;
        label = 'Rejected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
