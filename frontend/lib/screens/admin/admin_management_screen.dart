import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../models/user_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/beast_components.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdmins();
    });
  }

  void _loadAdmins() {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    provider.fetchAdmins(
      search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      status: _selectedStatus == 'all' ? null : _selectedStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isCurrentUserSuper = authProvider.user?.isSuperAdmin ?? false;

    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text('Institutional Administrators', style: BeastTypography.h3),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BeastColors.dark900),
            tooltip: 'Refresh Administrators',
            onPressed: _loadAdmins,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BeastColors.dark900,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Administrator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateAdminDialog(context),
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or ADM ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadAdmins();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _loadAdmins(),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusFilterChip('All Statuses', 'all'),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('Active', 'active'),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('Suspended', 'suspended'),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('Archived', 'archived'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main List View
          Expanded(
            child: adminProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : adminProvider.admins.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('No administrators found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Try adjusting your search query or status filter.', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadAdmins(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: adminProvider.admins.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final admin = adminProvider.admins[i];
                            final isSelf = admin.id == authProvider.user?.id;
                            return _buildAdminCard(context, admin, isSelf, isCurrentUserSuper);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: BeastColors.peach300.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? BeastColors.primary : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatus = value);
          _loadAdmins();
        }
      },
    );
  }

  Widget _buildAdminCard(BuildContext context, AdminUserModel admin, bool isSelf, bool isCurrentUserSuper) {
    String statusLabel = 'ACTIVE';
    if (admin.isSuspended) {
      statusLabel = 'SUSPENDED';
    } else if (admin.isArchived) {
      statusLabel = 'ARCHIVED';
    }

    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: admin.isSuperAdmin ? BeastColors.peach200 : BeastColors.neutral200,
                  borderRadius: BorderRadius.circular(BeastRadius.sm),
                ),
                child: Icon(
                  admin.isSuperAdmin ? Icons.workspace_premium : Icons.manage_accounts,
                  color: BeastColors.dark900,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            admin.name,
                            style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: BeastColors.peach100,
                              borderRadius: BorderRadius.circular(BeastRadius.xs),
                              border: Border.all(color: BeastColors.peach300),
                            ),
                            child: const Text('YOU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: BeastColors.dark900)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      admin.email,
                      style: BeastTypography.caption,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${admin.adminIdNumber}  •  ${admin.designation ?? 'Administrator'}',
                      style: BeastTypography.caption.copyWith(fontWeight: FontWeight.w600, color: BeastColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BeastBadge(
                    label: admin.isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN',
                    variant: admin.isSuperAdmin ? BeastBadgeVariant.peach : BeastBadgeVariant.neutral,
                  ),
                  const SizedBox(height: 6),
                  BeastStatusBadge(status: statusLabel),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Department & Employee ID Strip
          Row(
            children: [
              Icon(Icons.business_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                admin.department ?? 'General Administration',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const Spacer(),
              if (admin.phone != null && admin.phone!.isNotEmpty) ...[
                Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(admin.phone!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Audit Trail'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _showAuditTrailModal(context, admin),
              ),
              if (isCurrentUserSuper && !admin.isArchived) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => _showEditAdminDialog(context, admin),
                ),
                if (!admin.isSuspended && !isSelf)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.pause_circle_outline, size: 16, color: Colors.orange),
                    label: const Text('Suspend', style: TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: Colors.orange),
                    ),
                    onPressed: () => _showSuspendDialog(context, admin),
                  ),
                if (admin.isSuspended)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_circle_outline, size: 16, color: Colors.white),
                    label: const Text('Restore', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showRestoreDialog(context, admin),
                  ),
                if (!isSelf)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.archive_outlined, size: 16, color: Colors.red),
                    label: const Text('Archive', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _showArchiveDialog(context, admin),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // 1. Create Admin Dialog
  void _showCreateAdminDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'Academic Operations');
    final desigCtrl = TextEditingController(text: 'Operations Manager');
    final empIdCtrl = TextEditingController();

    bool manageStudents = true;
    bool manageTeachers = false;
    bool manageFinances = false;
    bool manageAcademics = true;
    bool viewAnalytics = true;
    bool isSuperAdmin = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Create New Administrator', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 10),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Official Email *', prefixIcon: Icon(Icons.email))),
                  const SizedBox(height: 10),
                  TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary Password *', prefixIcon: Icon(Icons.lock))),
                  const SizedBox(height: 10),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile Phone', prefixIcon: Icon(Icons.phone))),
                  const SizedBox(height: 10),
                  TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.business))),
                  const SizedBox(height: 10),
                  TextField(controller: desigCtrl, decoration: const InputDecoration(labelText: 'Designation', prefixIcon: Icon(Icons.badge))),
                  const SizedBox(height: 10),
                  TextField(controller: empIdCtrl, decoration: const InputDecoration(labelText: 'Employee Code / ID', prefixIcon: Icon(Icons.tag))),
                  const SizedBox(height: 16),
                  const Text('Granular Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Manage Students & Enrollments'),
                    value: manageStudents,
                    onChanged: (v) => setModalState(() => manageStudents = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Manage Faculty & Assignments'),
                    value: manageTeachers,
                    onChanged: (v) => setModalState(() => manageTeachers = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Manage Institutional Fees & Billing'),
                    value: manageFinances,
                    onChanged: (v) => setModalState(() => manageFinances = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Manage Classes, Batches & Timetable'),
                    value: manageAcademics,
                    onChanged: (v) => setModalState(() => manageAcademics = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('View Institutional Analytics'),
                    value: viewAnalytics,
                    onChanged: (v) => setModalState(() => viewAnalytics = v ?? false),
                  ),
                  SwitchListTile(
                    title: const Text('Grant Full Super Admin Access', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Allows managing administrators and institute-wide lifecycle'),
                    value: isSuperAdmin,
                    onChanged: (v) => setModalState(() => isSuperAdmin = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: BeastColors.primary),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required fields (Name, Email, Password)')));
                  return;
                }
                final permissions = {
                  'manage_students': manageStudents,
                  'manage_teachers': manageTeachers,
                  'manage_finances': manageFinances,
                  'manage_academics': manageAcademics,
                  'view_analytics': viewAnalytics,
                  'super_admin': isSuperAdmin,
                  'all': isSuperAdmin,
                };
                final ok = await Provider.of<AdminProvider>(context, listen: false).createAdmin(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  password: passwordCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  department: deptCtrl.text.trim(),
                  designation: desigCtrl.text.trim(),
                  employeeId: empIdCtrl.text.trim(),
                  permissions: permissions,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Administrator created successfully!' : 'Failed to create administrator.')),
                  );
                }
              },
              child: const Text('Create Admin', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Edit Admin Dialog
  void _showEditAdminDialog(BuildContext context, AdminUserModel admin) {
    final nameCtrl = TextEditingController(text: admin.name);
    final phoneCtrl = TextEditingController(text: admin.phone);
    final deptCtrl = TextEditingController(text: admin.department);
    final desigCtrl = TextEditingController(text: admin.designation);

    bool manageStudents = admin.permissions['manage_students'] ?? true;
    bool manageTeachers = admin.permissions['manage_teachers'] ?? false;
    bool manageFinances = admin.permissions['manage_finances'] ?? false;
    bool manageAcademics = admin.permissions['manage_academics'] ?? true;
    bool viewAnalytics = admin.permissions['view_analytics'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Edit Admin: ${admin.name}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                  const SizedBox(height: 10),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile Phone')),
                  const SizedBox(height: 10),
                  TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department')),
                  const SizedBox(height: 10),
                  TextField(controller: desigCtrl, decoration: const InputDecoration(labelText: 'Designation')),
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerLeft, child: Text('Permissions', style: TextStyle(fontWeight: FontWeight.bold))),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Manage Students'),
                    value: manageStudents,
                    onChanged: (v) => setModalState(() => manageStudents = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Manage Teachers'),
                    value: manageTeachers,
                    onChanged: (v) => setModalState(() => manageTeachers = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Manage Finances'),
                    value: manageFinances,
                    onChanged: (v) => setModalState(() => manageFinances = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('Manage Academics'),
                    value: manageAcademics,
                    onChanged: (v) => setModalState(() => manageAcademics = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    title: const Text('View Analytics'),
                    value: viewAnalytics,
                    onChanged: (v) => setModalState(() => viewAnalytics = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: BeastColors.primary),
              onPressed: () async {
                final permissions = {
                  ...admin.permissions,
                  'manage_students': manageStudents,
                  'manage_teachers': manageTeachers,
                  'manage_finances': manageFinances,
                  'manage_academics': manageAcademics,
                  'view_analytics': viewAnalytics,
                };
                final ok = await Provider.of<AdminProvider>(context, listen: false).updateAdmin(
                  admin.id,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  department: deptCtrl.text.trim(),
                  designation: desigCtrl.text.trim(),
                  permissions: permissions,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Admin updated!' : 'Failed to update admin.')),
                  );
                }
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Suspend Admin Dialog (Safety with Reason)
  void _showSuspendDialog(BuildContext context, AdminUserModel admin) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Suspend Administrator'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to suspend access for ${admin.name} (${admin.adminIdNumber})?'),
            const SizedBox(height: 8),
            const Text(
              'Impact: The administrator will be immediately logged out and unable to access institutional suites until restored.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason for suspension *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason.')));
                return;
              }
              final ok = await Provider.of<AdminProvider>(context, listen: false).suspendAdmin(admin.id, reasonCtrl.text.trim());
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Admin suspended.' : 'Failed to suspend admin.')),
                );
              }
            },
            child: const Text('Suspend Admin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 4. Restore Admin Dialog
  void _showRestoreDialog(BuildContext context, AdminUserModel admin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Administrator Access'),
        content: Text('Restore institutional access privileges for ${admin.name}? They will be able to log in immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final ok = await Provider.of<AdminProvider>(context, listen: false).restoreAdmin(admin.id);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Admin restored!' : 'Failed to restore admin.')),
                );
              }
            },
            child: const Text('Restore Access', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 5. Archive Admin Dialog (Double-Confirmation: Type "ARCHIVE")
  void _showArchiveDialog(BuildContext context, AdminUserModel admin) {
    final confirmCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Institutional contract concluded');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.delete_forever, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              const Text('Archive Administrator', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are about to ARCHIVE administrator ${admin.name} (${admin.adminIdNumber}).', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Safety Invariant: The account will be permanently deactivated from daily operations. Audit logs and records remain preserved (no hard delete).',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for Archival', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Text('To confirm, type "ARCHIVE" below:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: confirmCtrl,
                onChanged: (_) => setModalState(() {}),
                decoration: const InputDecoration(
                  hintText: 'ARCHIVE',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: confirmCtrl.text.trim() == 'ARCHIVE'
                  ? () async {
                      final ok = await Provider.of<AdminProvider>(context, listen: false).archiveAdmin(admin.id, reasonCtrl.text.trim());
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Admin archived successfully.' : 'Failed to archive admin.')),
                        );
                      }
                    }
                  : null,
              child: const Text('Permanently Archive', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 6. View Audit Trail Modal
  void _showAuditTrailModal(BuildContext context, AdminUserModel admin) async {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    final logs = await provider.fetchAdminAudit(admin.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Audit Trail: ${admin.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Admin ID: ${admin.adminIdNumber}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('No audit events recorded for this administrator.'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final log = logs[idx];
                          return ListTile(
                            leading: const CircleAvatar(
                              radius: 16,
                              backgroundColor: BeastColors.peach200,
                              child: Icon(Icons.bolt, size: 16, color: BeastColors.primary),
                            ),
                            title: Text(log['action'] ?? 'ACTION', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('Target: ${log['target_entity']} #${log['target_id']}\nAt: ${log['created_at']}'),
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
}
