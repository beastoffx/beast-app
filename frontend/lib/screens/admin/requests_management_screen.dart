import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/beast_components.dart';

class RequestsManagementScreen extends StatefulWidget {
  const RequestsManagementScreen({super.key});

  @override
  State<RequestsManagementScreen> createState() => _RequestsManagementScreenState();
}

class _RequestsManagementScreenState extends State<RequestsManagementScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _requests = [];
  String _statusFilter = 'PENDING';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isSuperAdmin = auth.isSuperAdmin || auth.user?.role == 'super_admin' || auth.user?.activeRole == 'super_admin';

    String endpoint = ApiConstants.requests;
    if (isSuperAdmin) {
      if (_statusFilter == 'PENDING') {
        // Backend default for Super Admin returns PENDING_SUPER_ADMIN_REVIEW + PENDING_ADMIN_REVIEW
        endpoint = ApiConstants.requests;
      } else if (_statusFilter != 'ALL') {
        endpoint = '${ApiConstants.requests}?status=$_statusFilter';
      } else {
        endpoint = '${ApiConstants.requests}?status=ALL';
      }
    } else {
      endpoint = '${ApiConstants.requests}?status=PENDING_ADMIN_REVIEW';
    }

    try {
      final res = await _api.get(endpoint, useCache: false);
      if (res.success && res.data != null) {
        setState(() {
          _requests = res.data is List ? res.data : (res.data['data'] ?? []);
        });
      } else {
        setState(() => _error = res.error ?? 'Failed to load onboarding requests.');
      }
    } catch (e) {
      setState(() => _error = 'Network error loading requests: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete(String id, String applicantName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Application'),
        content: Text('Are you sure you want to permanently delete the application for "$applicantName"? This action cannot be undone.'),
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

    if (confirm != true) return;

    try {
      final res = await _api.delete(ApiConstants.requestDelete(id));
      if (res.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application deleted successfully.'), backgroundColor: BeastColors.success),
        );
        _loadRequests();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error ?? 'Failed to delete application.'), backgroundColor: BeastColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: BeastColors.error),
      );
    }
  }

  Future<void> _handleReview(String id, String action, {String? notes, String? reason}) async {
    try {
      final endpoint = '${ApiConstants.requests}/$id/review';
      final body = {
        'action': action,
        if (notes != null && notes.isNotEmpty) 'reviewNotes': notes,
        if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
      };

      final res = await _api.post(endpoint, body);
      if (res.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.data?['message'] ?? (action == 'approve' ? 'Request approved successfully.' : 'Request rejected.')),
            backgroundColor: action == 'approve' ? BeastColors.success : BeastColors.error,
          ),
        );
        _loadRequests();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error ?? 'Review action failed.'), backgroundColor: BeastColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: BeastColors.error),
      );
    }
  }

  void _showRejectDialog(String id, String applicantName) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Application', style: BeastTypography.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applicant: $applicantName', style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Please provide a formal institutional reason for rejection.',
              style: BeastTypography.caption,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                hintText: 'e.g. Quota full, prerequisites incomplete',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: BeastColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BeastColors.error, foregroundColor: Colors.white),
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required.')));
                return;
              }
              Navigator.pop(ctx);
              _handleReview(id, 'reject', reason: reason);
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> req) {
    final notesController = TextEditingController();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isSuperAdmin = auth.isSuperAdmin || auth.user?.role == 'super_admin' || auth.user?.activeRole == 'super_admin';
    final role = req['requested_role'] as String? ?? 'student';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(isSuperAdmin ? Icons.verified_user : Icons.check_circle,
                color: isSuperAdmin ? BeastColors.peach400 : BeastColors.success),
            const SizedBox(width: 8),
            Text(isSuperAdmin ? 'Executive Activation' : 'Approve & Forward', style: BeastTypography.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applicant: ${req['name']} (${role.toUpperCase()})',
                style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              isSuperAdmin
                  ? 'Authorizing this application will atomically generate official collision-safe credentials and activate the account.'
                  : 'Approving this request will advance it to Super Administrator for final executive activation.',
              style: BeastTypography.caption,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Review Notes (Optional)',
                hintText: 'e.g. Admission quota cleared',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: BeastColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BeastColors.dark900,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _handleReview(req['id'], 'approve', notes: notesController.text.trim());
            },
            child: Text(isSuperAdmin ? 'Activate Account' : 'Approve & Forward'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isSuperAdmin = auth.isSuperAdmin || auth.user?.role == 'super_admin' || auth.user?.activeRole == 'super_admin';

    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text(isSuperAdmin ? 'Executive Approvals Queue' : 'Institutional Onboarding Queue', style: BeastTypography.h3),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BeastColors.dark900),
            onPressed: _loadRequests,
            tooltip: 'Refresh Queue',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter strip for Super Admin
          if (isSuperAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.sm),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Pending Final Action', 'PENDING'),
                    const SizedBox(width: 8),
                    _buildFilterChip('All Requests', 'ALL'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Approved', 'APPROVED'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Rejected', 'REJECTED'),
                  ],
                ),
              ),
            ),
          if (isSuperAdmin) const Divider(height: 1, color: BeastColors.borderSubtle),

          Expanded(
            child: _isLoading
                ? const Center(child: BeastLoadingState(message: 'Loading candidate applications...'))
                : _error != null
                    ? Center(
                        child: BeastErrorState(
                          title: 'Failed to load requests',
                          message: _error!,
                          onRetry: _loadRequests,
                        ),
                      )
                    : _requests.isEmpty
                        ? const Center(
                            child: BeastEmptyState(
                              icon: Icons.check_circle_outline,
                              title: 'Queue is Clear',
                              subtitle: 'All onboarding applications have been reviewed.',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(BeastSpacing.lg),
                            itemCount: _requests.length,
                            separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                            itemBuilder: (ctx, i) => _buildRequestCard(_requests[i], isSuperAdmin),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: BeastColors.peach200,
      backgroundColor: BeastColors.neutral100,
      onSelected: (selected) {
        if (selected) {
          setState(() => _statusFilter = value);
          _loadRequests();
        }
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req, bool isSuperAdmin) {
    final status = (req['status']?.toString() ?? '').trim().toUpperCase();
    final role = (req['requested_role']?.toString() ?? 'student').trim().toLowerCase();
    final isPending = status != 'APPROVED' && status != 'REJECTED';
    // Super Admin can review/accept/deny all pending requests. Admin can review pending student/teacher requests.
    final canReview = isSuperAdmin ? isPending : (isPending && role != 'admin');

    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: BeastColors.peach200,
                    child: Icon(_getRoleIcon(role), color: BeastColors.dark900, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req['name'] ?? 'Applicant', style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                      Text(req['email'] ?? '', style: BeastTypography.caption),
                    ],
                  ),
                ],
              ),
              BeastStatusBadge(status: status),
            ],
          ),
          const Divider(height: 20, color: BeastColors.borderSubtle),

          // Application Details
          if (role == 'student') ...[
            Text('Class: ${req['class_name'] ?? 'Class'} • Batch: ${req['batch_name'] ?? 'N/A'}',
                style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            if (req['session_name'] != null)
              Text('Academic Session: ${req['session_name']}', style: BeastTypography.caption),
          ],
          if (role == 'teacher') ...[
            Text('Qualification: ${req['qualification'] ?? 'N/A'}',
                style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            if (req['department'] != null)
              Text('Department: ${req['department']}', style: BeastTypography.caption),
          ],
          if (role == 'admin') ...[
            Text('Department: ${req['department'] ?? 'Administration'}',
                style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          ],

          if (req['phone'] != null && req['phone'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Phone: ${req['phone']}', style: BeastTypography.caption),
            ),

          if (req['notes'] != null && req['notes'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Applicant Notes: "${req['notes']}"',
                  style: BeastTypography.caption.copyWith(fontStyle: FontStyle.italic)),
            ),

          // Prior reviewer notes
          if (req['teacher_review_notes'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Faculty Review: "${req['teacher_review_notes']}"',
                  style: BeastTypography.caption.copyWith(color: Colors.teal, fontWeight: FontWeight.w600)),
            ),
          if (req['admin_review_notes'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Admin Clearance: "${req['admin_review_notes']}"',
                  style: BeastTypography.caption.copyWith(color: Colors.blue, fontWeight: FontWeight.w600)),
            ),

          if (status == 'APPROVED' && req['generated_student_id'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: BeastColors.successLight, borderRadius: BorderRadius.circular(BeastRadius.xs)),
                child: Text('Activated Official Student ID: ${req['generated_student_id']}',
                    style: const TextStyle(color: BeastColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),

          if (status == 'REJECTED' && req['rejection_reason'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: BeastColors.errorLight, borderRadius: BorderRadius.circular(BeastRadius.xs)),
                child: Text('Rejection Reason: ${req['rejection_reason']}',
                    style: const TextStyle(color: BeastColors.error, fontSize: 12)),
              ),
            ),

          // Action Buttons: Allow / Deny / Delete
          const SizedBox(height: 16),
          const Divider(height: 1, color: BeastColors.borderSubtle),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _handleDelete(req['id'], req['name'] ?? 'Applicant'),
                icon: const Icon(Icons.delete_forever, size: 18, color: BeastColors.error),
                label: const Text('Delete', style: TextStyle(color: BeastColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(req['id'], req['name'] ?? 'Applicant'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BeastColors.error,
                      side: const BorderSide(color: BeastColors.error, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.close, size: 16, color: BeastColors.error),
                    label: const Text('Deny', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(req),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BeastColors.dark900,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      isSuperAdmin ? 'Allow & Activate' : 'Allow & Forward',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'student':
        return Icons.school;
      case 'teacher':
        return Icons.person;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.account_circle;
    }
  }
}
