import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password (min 6 chars)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final ok = await auth.changePassword(
                currentPassController.text,
                newPassController.text,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Password changed successfully.' : (auth.errorMessage ?? 'Failed to change password.')),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Save Password'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Institutional Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Avatar & Role Banner
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : 'U',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.secondary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Academic Profile Details
              const Text('Academic Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  children: [
                    if (auth.isStudent && auth.studentProfile != null) ...[
                      _buildDetailRow('Student ID', auth.studentProfile!.studentIdNumber),
                      const Divider(height: 16),
                      _buildDetailRow('Enrolled Batch', auth.studentProfile!.batchName ?? 'PCM-2027-A'),
                      const Divider(height: 16),
                      _buildDetailRow('Class', auth.studentProfile!.className ?? 'Class 12 Science'),
                      const Divider(height: 16),
                      _buildDetailRow('Academic Session', auth.studentProfile!.sessionName ?? '2026-2027'),
                    ] else if (auth.isTeacher && auth.teacherProfile != null) ...[
                      _buildDetailRow('Employee Code', auth.teacherProfile!['employee_code'] ?? 'TCH-001'),
                      const Divider(height: 16),
                      _buildDetailRow('Qualification', auth.teacherProfile!['qualification'] ?? 'N/A'),
                      const Divider(height: 16),
                      _buildDetailRow('Specialization', auth.teacherProfile!['bio'] ?? 'N/A'),
                    ] else ...[
                      _buildDetailRow('Designation', 'Institutional Director & Administrator'),
                      const Divider(height: 16),
                      _buildDetailRow('Permissions', 'Full Campus RBAC Super-Admin'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Security & Privacy Settings
              const Text('Security & Institutional Governance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_reset, color: AppColors.primary),
                      title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Update your institutional account credentials', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _showChangePasswordDialog(context),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                      title: const Text('Privacy & Data Governance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Free-first, zero tracking, strict academic privacy', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('B.E.A.S.T ACADEMY Privacy Charter'),
                            content: const Text(
                              '• Student data is never sold or shared with third parties.\n'
                              '• Zero mandatory paid SaaS or cloud tracking dependencies.\n'
                              '• Academic records and doubts remain exclusively between student and faculty.\n'
                              '• All passwords hashed with industry standard bcrypt.\n'
                              '• Relational ACID database with full RBAC enforcement.',
                              style: TextStyle(fontSize: 13, height: 1.5),
                            ),
                            actions: [
                              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
                            ],
                          ),
                        );
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sign Out Button
              OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                },
                icon: const Icon(Icons.logout, color: AppColors.error, size: 18),
                label: const Text('Sign Out of Academy', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 16),

              const Center(
                child: Text(
                  'B.E.A.S.T ACADEMY v1.0.0 • Production Build',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}
