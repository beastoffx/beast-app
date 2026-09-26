import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/beast_tokens.dart';
import '../../widgets/beast_components.dart';

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _teachers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _api.get(ApiConstants.academicsTeachers, useCache: false);
    if (!mounted) return;

    if (res.success && res.data != null) {
      setState(() {
        _teachers = res.data as List? ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res.error ?? 'Failed to load faculty directory.';
        _isLoading = false;
      });
    }
  }

  void _showAddTeacherDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final empIdCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final qualCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BeastRadius.md),
          ),
          backgroundColor: BeastColors.white,
          title: const Text('Add Faculty Member', style: BeastTypography.title),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: BeastSpacing.md),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email Address *'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                    ),
                    const SizedBox(height: BeastSpacing.md),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: BeastSpacing.md),
                    TextFormField(
                      controller: empIdCtrl,
                      decoration: const InputDecoration(labelText: 'Employee ID *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: BeastSpacing.md),
                    TextFormField(
                      controller: deptCtrl,
                      decoration: const InputDecoration(labelText: 'Department / Specialization'),
                    ),
                    const SizedBox(height: BeastSpacing.md),
                    TextFormField(
                      controller: qualCtrl,
                      decoration: const InputDecoration(labelText: 'Qualification (e.g. M.Sc, Ph.D)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);

                      final res = await _api.post(ApiConstants.academicsTeachers, {
                        'full_name': nameCtrl.text.trim(),
                        'email': emailCtrl.text.trim().toLowerCase(),
                        'phone_number': phoneCtrl.text.trim(),
                        'employee_id': empIdCtrl.text.trim(),
                        'department': deptCtrl.text.trim(),
                        'qualification': qualCtrl.text.trim(),
                      });

                      if (mounted) {
                        Navigator.pop(ctx);
                        if (res.success) {
                          _fetchTeachers();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Faculty member added successfully.'),
                              backgroundColor: BeastColors.success,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.error ?? 'Failed to add teacher.'),
                              backgroundColor: BeastColors.danger,
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Faculty'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _teachers.where((t) {
      final name = (t['full_name'] ?? t['name'] ?? '').toString().toLowerCase();
      final empId = (t['employee_id'] ?? '').toString().toLowerCase();
      final dept = (t['department'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || empId.contains(q) || dept.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Faculty Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchTeachers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTeacherDialog,
        backgroundColor: BeastColors.brandPrimary,
        foregroundColor: BeastColors.white,
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text('Add Faculty'),
      ),
      body: _buildBody(filtered),
    );
  }

  Widget _buildBody(List<dynamic> filtered) {
    if (_isLoading) {
      return const BeastLoadingState(message: 'Loading faculty directory...');
    }

    if (_errorMessage != null) {
      return BeastErrorState(
        message: _errorMessage!,
        onRetry: _fetchTeachers,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(BeastSpacing.lg),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by faculty name, ID, or department...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? BeastEmptyState(
                  icon: Icons.school_outlined,
                  title: _searchQuery.isEmpty ? 'No Faculty Registered' : 'No Results Found',
                  message: _searchQuery.isEmpty
                      ? 'No teaching faculty members are currently registered.'
                      : 'No faculty matched "$_searchQuery".',
                )
              : RefreshIndicator(
                  onRefresh: _fetchTeachers,
                  color: BeastColors.brandPrimary,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(
                      left: BeastSpacing.lg,
                      right: BeastSpacing.lg,
                      bottom: 80,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.sm),
                    itemBuilder: (context, index) {
                      final teacher = filtered[index];
                      final name = teacher['full_name'] ?? teacher['name'] ?? 'Faculty Member';
                      final empId = teacher['employee_id'] ?? 'N/A';
                      final dept = teacher['department'] ?? 'General';
                      final email = teacher['email'] ?? '';
                      final phone = teacher['phone_number'] ?? '';

                      return BeastCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: BeastColors.peach200,
                                borderRadius: BorderRadius.circular(BeastRadius.sm),
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: BeastColors.dark900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: BeastSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(name, style: BeastTypography.bodyMedium),
                                      ),
                                      BeastBadge(
                                        label: empId,
                                        backgroundColor: BeastColors.surfaceWarm,
                                        textColor: BeastColors.dark900,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dept,
                                    style: BeastTypography.caption.copyWith(
                                      color: BeastColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (email.isNotEmpty) ...[
                                        const Icon(Icons.email_outlined, size: 13, color: BeastColors.textMuted),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            email,
                                            style: BeastTypography.caption,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      if (phone.isNotEmpty) ...[
                                        const SizedBox(width: 12),
                                        const Icon(Icons.phone_outlined, size: 13, color: BeastColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text(phone, style: BeastTypography.caption),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
