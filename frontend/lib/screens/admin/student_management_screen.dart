import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/beast_components.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';
  String _selectedSubscription = 'all';
  String? _selectedClassId;
  String? _selectedBatchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      provider.fetchAcademics();
      _loadStudents();
    });
  }

  void _loadStudents() {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    provider.fetchStudentsFiltered(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      status: _selectedStatus == 'all' ? null : _selectedStatus,
      subscriptionStatus: _selectedSubscription == 'all' ? null : _selectedSubscription,
      classId: _selectedClassId,
      batchId: _selectedBatchId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Lifecycle Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Students',
            onPressed: _loadStudents,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Enroll Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showEnrollStudentDialog(context),
      ),
      body: Column(
        children: [
          // Filter & Search Controls Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by student name, ID (BST-...), phone, email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadStudents();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _loadStudents(),
                ),
                const SizedBox(height: 12),

                // Status Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      _buildChip('All', _selectedStatus == 'all', () {
                        setState(() => _selectedStatus = 'all');
                        _loadStudents();
                      }),
                      const SizedBox(width: 6),
                      _buildChip('Active', _selectedStatus == 'active', () {
                        setState(() => _selectedStatus = 'active');
                        _loadStudents();
                      }),
                      const SizedBox(width: 6),
                      _buildChip('Pending', _selectedStatus == 'pending_activation', () {
                        setState(() => _selectedStatus = 'pending_activation');
                        _loadStudents();
                      }),
                      const SizedBox(width: 6),
                      _buildChip('Suspended', _selectedStatus == 'suspended', () {
                        setState(() => _selectedStatus = 'suspended');
                        _loadStudents();
                      }),
                      const SizedBox(width: 6),
                      _buildChip('Archived', _selectedStatus == 'archived', () {
                        setState(() => _selectedStatus = 'archived');
                        _loadStudents();
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Subscription Chips & Class/Batch Dropdowns
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Plan: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      _buildChip('All Plans', _selectedSubscription == 'all', () {
                        setState(() => _selectedSubscription = 'all');
                        _loadStudents();
                      }),
                      const SizedBox(width: 6),
                      _buildChip('Paid Tier', _selectedSubscription == 'paid', () {
                        setState(() => _selectedSubscription = 'paid');
                        _loadStudents();
                      }),
                      const SizedBox(width: 6),
                      _buildChip('Free Tier', _selectedSubscription == 'free', () {
                        setState(() => _selectedSubscription = 'free');
                        _loadStudents();
                      }),
                      const SizedBox(width: 6),
                      _buildChip('Expired', _selectedSubscription == 'expired', () {
                        setState(() => _selectedSubscription = 'expired');
                        _loadStudents();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Students List
          Expanded(
            child: admin.isLoading
                ? const Center(child: CircularProgressIndicator())
                : admin.studentsList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('No students matched your search criteria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Try broadening your filters.', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadStudents(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: admin.studentsList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final s = admin.studentsList[i];
                            return _buildStudentCard(context, s);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? BeastColors.peach200 : BeastColors.neutral100,
          borderRadius: BorderRadius.circular(BeastRadius.xs),
          border: Border.all(color: isSelected ? BeastColors.peach400 : BeastColors.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? BeastColors.dark900 : BeastColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, dynamic s) {
    final status = s['user_status'] ?? s['status'] ?? 'active';
    final subscription = s['subscription_status'] ?? 'paid';
    final studentId = s['student_id_number'] ?? 'N/A';
    final name = s['name'] ?? 'Student';
    final email = s['email'] ?? '';
    final className = s['class_name'] ?? 'Class';
    final batchName = s['batch_name'] ?? 'Batch';
    final userId = s['id'] ?? '';

    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BeastColors.peach200,
                  borderRadius: BorderRadius.circular(BeastRadius.sm),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: BeastColors.dark900, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(email, style: BeastTypography.caption),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $studentId  •  $className ($batchName)',
                      style: BeastTypography.caption.copyWith(fontWeight: FontWeight.w600, color: BeastColors.textSecondary),
                    ),
                  ],
                ),
              ),
              BeastStatusBadge(status: status.toString().toUpperCase()),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Lifecycle Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.analytics_outlined, size: 15),
                label: const Text('Detail & Stats'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _showStudentDetailModal(context, userId),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_note, size: 15),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _showEditProfileDialog(context, s),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.card_membership, size: 15),
                label: const Text('Subscription'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _showSubscriptionDialog(context, s),
              ),
              if (status != 'suspended' && status != 'archived')
                OutlinedButton.icon(
                  icon: const Icon(Icons.pause_circle_outline, size: 15, color: Colors.orange),
                  label: const Text('Suspend', style: TextStyle(color: Colors.orange)),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, side: const BorderSide(color: Colors.orange)),
                  onPressed: () => _showSuspendDialog(context, userId, name, studentId),
                ),
              if (status == 'suspended')
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_circle_outline, size: 15, color: Colors.white),
                  label: const Text('Restore', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, visualDensity: VisualDensity.compact),
                  onPressed: () => _showRestoreDialog(context, userId, name),
                ),
              if (status != 'archived')
                OutlinedButton.icon(
                  icon: const Icon(Icons.archive_outlined, size: 15, color: Colors.red),
                  label: const Text('Archive', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, side: const BorderSide(color: Colors.red)),
                  onPressed: () => _showArchiveDialog(context, userId, name, studentId),
                ),
              if (status == 'archived')
                ElevatedButton.icon(
                  icon: const Icon(Icons.unarchive_outlined, size: 15, color: Colors.white),
                  label: const Text('Restore Account', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, visualDensity: VisualDensity.compact),
                  onPressed: () => _showRestoreDialog(context, userId, name),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 1. Student Detail & Stats Drawer/Modal
  void _showStudentDetailModal(BuildContext context, String studentUserId) async {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    final detail = await provider.fetchStudentDetail(studentUserId);

    if (!mounted || detail == null) return;

    final stats = detail['stats'] ?? {};
    final attendanceTotal = stats['attendanceTotal'] ?? 0;
    final attendancePresent = stats['attendancePresent'] ?? 0;
    final attendancePct = stats['attendancePercentage'] ?? 0.0;
    final submissionCount = stats['assignmentSubmissions'] ?? 0;
    final doubtsCount = stats['doubtsRaised'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(detail['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Official ID: ${detail['student_id_number']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 24),

              // Academic Progress Metrics
              const Text('Academic Progress Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        children: [
                          const Text('Attendance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text('${attendancePct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                          const SizedBox(height: 2),
                          Text('$attendancePresent / $attendanceTotal lectures', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        children: [
                          const Text('Submissions', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text('$submissionCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                          const SizedBox(height: 2),
                          const Text('Total completed', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        children: [
                          const Text('Doubts Raised', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text('$doubtsCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                          const SizedBox(height: 2),
                          const Text('In DoubtDeck', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Verification & Security
              const Text('Identity & Authentication State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                leading: Icon(detail['google_uid'] != null ? Icons.check_circle : Icons.radio_button_unchecked, color: detail['google_uid'] != null ? Colors.green : Colors.grey),
                title: const Text('Google SSO Linked'),
                subtitle: Text(detail['google_uid'] != null ? 'UID: ${detail['google_uid']}' : 'Account not linked yet'),
              ),
              ListTile(
                dense: true,
                leading: Icon(detail['phone_verified'] == 1 ? Icons.verified : Icons.phonelink_erase, color: detail['phone_verified'] == 1 ? Colors.green : Colors.orange),
                title: const Text('Phone Number Verified'),
                subtitle: Text(detail['phone'] ?? 'No phone registered'),
              ),
              const SizedBox(height: 16),

              // Subscription & Resource Limits
              const Text('Current Subscription Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subscription Tier:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text((detail['subscription_status'] ?? 'paid').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Access Valid Until:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(detail['access_end_date'] ?? 'Lifetime / Session End'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Audit History Button
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('View Full Student Audit History'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showStudentAuditModal(context, studentUserId, detail['name'] ?? 'Student');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Suspend Dialog
  void _showSuspendDialog(BuildContext context, String studentUserId, String name, String studentId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend Student Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suspend institutional access for $name ($studentId)?'),
            const SizedBox(height: 8),
            const Text(
              'Impact: The student will be instantly blocked from logging in, accessing lectures, and downloading study materials.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Suspension Reason *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              final ok = await Provider.of<AdminProvider>(context, listen: false).suspendStudent(studentUserId, reasonCtrl.text.trim());
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Student suspended.' : 'Failed to suspend student.')));
              }
            },
            child: const Text('Suspend Student', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 3. Restore Dialog
  void _showRestoreDialog(BuildContext context, String studentUserId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Student Access'),
        content: Text('Reactivate institutional access for $name? They will be able to log in and access curriculum materials again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final ok = await Provider.of<AdminProvider>(context, listen: false).restoreStudent(studentUserId);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Student access restored!' : 'Failed to restore student.')));
              }
            },
            child: const Text('Restore Access', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 4. Archive Dialog (Soft Deletion Safety)
  void _showArchiveDialog(BuildContext context, String studentUserId, String name, String studentId) {
    final reasonCtrl = TextEditingController(text: 'Course completed / Graduated');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Student (Soft Delete)', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to ARCHIVE $name ($studentId)?', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Safety Guarantee: All historical attendance records, doubt discussions, exam results, and fee transactions are preserved forever in the database. The student can no longer sign in.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Archival Reason', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await Provider.of<AdminProvider>(context, listen: false).archiveStudent(studentUserId, reasonCtrl.text.trim());
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Student archived.' : 'Failed to archive student.')));
              }
            },
            child: const Text('Archive Student', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 5. Subscription Management Dialog
  void _showSubscriptionDialog(BuildContext context, dynamic s) {
    String currentSub = s['subscription_status'] ?? 'paid';
    final expiryCtrl = TextEditingController(text: s['access_end_date'] ?? '2027-12-31');

    bool materials = true;
    bool doubts = true;
    bool exams = true;
    bool lectures = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Manage Subscription: ${s['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: currentSub,
                decoration: const InputDecoration(labelText: 'Subscription Status'),
                items: const [
                  DropdownMenuItem(value: 'paid', child: Text('Paid Tier (Full Access)')),
                  DropdownMenuItem(value: 'free', child: Text('Free Tier (Limited)')),
                  DropdownMenuItem(value: 'expired', child: Text('Expired / Default')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => currentSub = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiryCtrl,
                decoration: const InputDecoration(labelText: 'Access End Date (YYYY-MM-DD)', hintText: '2027-12-31'),
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Resource Permissions', style: TextStyle(fontWeight: FontWeight.bold))),
              CheckboxListTile(
                dense: true,
                title: const Text('Study Materials Access'),
                value: materials,
                onChanged: (v) => setModalState(() => materials = v ?? true),
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Test Series & Exams'),
                value: exams,
                onChanged: (v) => setModalState(() => exams = v ?? true),
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Live Lectures & Timetable'),
                value: lectures,
                onChanged: (v) => setModalState(() => lectures = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final permissions = {
                  'materials': materials,
                  'doubts': doubts,
                  'exams': exams,
                  'live_lectures': lectures,
                };
                final ok = await Provider.of<AdminProvider>(context, listen: false).updateStudentSubscription(
                  s['id'],
                  subscriptionStatus: currentSub,
                  accessEndDate: expiryCtrl.text.trim().isEmpty ? null : expiryCtrl.text.trim(),
                  resourcePermissions: permissions,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Subscription updated!' : 'Failed to update subscription.')));
                }
              },
              child: const Text('Save Subscription', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Edit Profile Dialog
  void _showEditProfileDialog(BuildContext context, dynamic s) {
    final nameCtrl = TextEditingController(text: s['name']);
    final phoneCtrl = TextEditingController(text: s['phone']);
    final emergCtrl = TextEditingController(text: s['emergency_contact']);
    final admin = Provider.of<AdminProvider>(context, listen: false);

    String? selectedClassId = s['class_id'];
    String? selectedBatchId = s['batch_id'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Edit Profile: ${s['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Student Full Name')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile Phone')),
                const SizedBox(height: 10),
                TextField(controller: emergCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedClassId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: admin.classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (val) => setModalState(() => selectedClassId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedBatchId,
                  decoration: const InputDecoration(labelText: 'Batch'),
                  items: admin.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setModalState(() => selectedBatchId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final ok = await Provider.of<AdminProvider>(context, listen: false).updateStudentProfile(
                  s['id'],
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  emergencyContact: emergCtrl.text.trim(),
                  classId: selectedClassId,
                  batchId: selectedBatchId,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Profile updated!' : 'Failed to update profile.')));
                }
              },
              child: const Text('Save Profile', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 7. Student Audit History Modal
  void _showStudentAuditModal(BuildContext context, String studentUserId, String studentName) async {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    final logs = await provider.fetchStudentAudit(studentUserId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Audit History: $studentName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('No audit events found for this student.'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final log = logs[idx];
                          return ListTile(
                            leading: const CircleAvatar(radius: 14, child: Icon(Icons.security, size: 14)),
                            title: Text(log['action'] ?? 'ACTION', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('By: ${log['actor_name'] ?? 'Admin'} (${log['actor_role'] ?? 'admin'})\nAt: ${log['created_at']}'),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 8. Enroll Student Dialog
  void _showEnrollStudentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'Student@123');
    final idCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emergCtrl = TextEditingController();

    final admin = Provider.of<AdminProvider>(context, listen: false);
    String selectedClassId = admin.classes.isNotEmpty ? admin.classes.first.id : 'class-12-sci';
    String selectedBatchId = admin.batches.isNotEmpty ? admin.batches.first.id : 'batch-pcm-2027-a';
    String selectedSessionId = admin.sessions.isNotEmpty ? admin.sessions.first.id : 'session-2026-2027';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Enroll New Student', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                const SizedBox(height: 10),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Student Email *')),
                const SizedBox(height: 10),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Initial Password *')),
                const SizedBox(height: 10),
                TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'Student ID Number (Leave empty to auto-generate)')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Student Mobile Phone')),
                const SizedBox(height: 10),
                TextField(controller: emergCtrl, decoration: const InputDecoration(labelText: 'Parent / Emergency Contact')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedClassId,
                  decoration: const InputDecoration(labelText: 'Assigned Class'),
                  items: admin.classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedClassId = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedBatchId,
                  decoration: const InputDecoration(labelText: 'Assigned Batch'),
                  items: admin.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedBatchId = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Email are required.')));
                  return;
                }
                final ok = await admin.createStudent(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  studentIdNumber: idCtrl.text.trim(),
                  classId: selectedClassId,
                  batchId: selectedBatchId,
                  sessionId: selectedSessionId,
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  emergencyContact: emergCtrl.text.trim().isEmpty ? null : emergCtrl.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadStudents();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Student enrolled successfully!' : 'Failed to enroll student.')));
                }
              },
              child: const Text('Enroll Student', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
