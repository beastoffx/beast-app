import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/beast_tokens.dart';
import '../../widgets/beast_components.dart';

class TeacherRequestsScreen extends StatefulWidget {
  const TeacherRequestsScreen({super.key});

  @override
  State<TeacherRequestsScreen> createState() => _TeacherRequestsScreenState();
}

class _TeacherRequestsScreenState extends State<TeacherRequestsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _requests = [];

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

    try {
      final res = await _api.get('${ApiConstants.requests}?status=PENDING_TEACHER_REVIEW', useCache: false);
      if (res.success && res.data != null) {
        setState(() {
          _requests = res.data is List ? res.data : (res.data['data'] ?? []);
        });
      } else {
        setState(() => _error = res.error ?? 'Failed to load student applications.');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            content: Text(res.data?['message'] ?? (action == 'approve' ? 'Approved & forwarded to administration.' : 'Application rejected.')),
            backgroundColor: action == 'approve' ? BeastColors.success : BeastColors.danger,
          ),
        );
        _loadRequests();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error ?? 'Review action failed.'), backgroundColor: BeastColors.danger),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: BeastColors.danger),
      );
    }
  }

  void _showApproveDialog(Map<String, dynamic> req) {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.md)),
        backgroundColor: BeastColors.white,
        title: const Text('Faculty Verification Approval', style: BeastTypography.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applicant: ${req['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text('Class: ${req['class_name'] ?? 'Class'} • Batch: ${req['batch_name'] ?? 'N/A'}',
                style: BeastTypography.caption),
            const SizedBox(height: BeastSpacing.md),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Faculty Recommendation Notes (Optional)',
                hintText: 'e.g. Academic prerequisites verified.',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleReview(req['id'].toString(), 'approve', notes: notesController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: BeastColors.brandPrimary, foregroundColor: Colors.white),
            child: const Text('Approve & Forward'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> req) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.md)),
        backgroundColor: BeastColors.white,
        title: const Text('Reject Application', style: BeastTypography.title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Applicant: ${req['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: BeastSpacing.md),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Mandatory Rejection Justification *',
                  hintText: 'e.g. Prerequisites not met.',
                ),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Rejection reason is mandatory' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                _handleReview(req['id'].toString(), 'reject', reason: reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: BeastColors.danger, foregroundColor: Colors.white),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Academic Verification Queue'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', onPressed: _loadRequests),
        ],
      ),
      body: _isLoading
          ? const BeastLoadingState(message: 'Loading candidate applications...')
          : _error != null
              ? BeastErrorState(message: _error!, onRetry: _loadRequests)
              : _requests.isEmpty
                  ? const BeastEmptyState(
                      icon: Icons.how_to_reg_outlined,
                      title: 'Queue Clear',
                      message: 'No student onboarding applications currently require faculty review.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      color: BeastColors.brandPrimary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(BeastSpacing.lg),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                        itemBuilder: (ctx, i) {
                          final req = _requests[i];
                          return BeastCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(req['name'] ?? 'Candidate', style: BeastTypography.title),
                                    const BeastBadge(
                                      label: 'Awaiting Faculty',
                                      backgroundColor: BeastColors.peach200,
                                      textColor: BeastColors.dark900,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Class: ${req['class_name'] ?? 'N/A'} • Batch: ${req['batch_name'] ?? 'N/A'}',
                                  style: BeastTypography.bodyMedium.copyWith(color: BeastColors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Email: ${req['email']} • Phone: ${req['phone'] ?? req['phone_number'] ?? 'N/A'}',
                                  style: BeastTypography.caption,
                                ),
                                if (req['notes'] != null && req['notes'].toString().isNotEmpty) ...[
                                  const SizedBox(height: BeastSpacing.sm),
                                  Text('Background: ${req['notes']}', style: BeastTypography.caption),
                                ],
                                const SizedBox(height: BeastSpacing.md),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _showRejectDialog(req),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: BeastColors.danger,
                                        side: const BorderSide(color: BeastColors.danger),
                                      ),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Deny'),
                                    ),
                                    const SizedBox(width: BeastSpacing.md),
                                    ElevatedButton.icon(
                                      onPressed: () => _showApproveDialog(req),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: BeastColors.brandPrimary,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Allow & Recommend'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
