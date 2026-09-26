import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/beast_components.dart';
import '../../widgets/beast_logo.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Password', style: BeastTypography.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password (min 6 chars)', border: OutlineInputBorder()),
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
                    backgroundColor: ok ? BeastColors.success : BeastColors.error,
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
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text('Profile & Institutional Settings', style: BeastTypography.h3),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeastSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User Avatar & Role Banner
                BeastCard(
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: BeastColors.peach200,
                          borderRadius: BorderRadius.circular(BeastRadius.md),
                        ),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: BeastColors.dark900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: BeastTypography.h3,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: BeastTypography.caption,
                            ),
                            const SizedBox(height: 8),
                            BeastBadge(
                              label: user.role.toUpperCase(),
                              variant: BeastBadgeVariant.peach,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BeastSpacing.lg),

                // Academic Profile Details
                Text('Academic Credentials', style: BeastTypography.h3),
                const SizedBox(height: BeastSpacing.sm),
                BeastCard(
                  child: Column(
                    children: [
                      if (auth.isStudent && auth.studentProfile != null) ...[
                        _buildDetailRow('Student ID', auth.studentProfile!.studentIdNumber),
                        const Divider(height: 20, color: BeastColors.borderSubtle),
                        _buildDetailRow('Enrolled Batch', auth.studentProfile!.batchName ?? 'PCM-2027-A'),
                        const Divider(height: 20, color: BeastColors.borderSubtle),
                        _buildDetailRow('Class', auth.studentProfile!.className ?? 'Class 12 Science'),
                        const Divider(height: 20, color: BeastColors.borderSubtle),
                        _buildDetailRow('Academic Session', auth.studentProfile!.sessionName ?? '2026-2027'),
                      ] else if (auth.isTeacher && auth.teacherProfile != null) ...[
                        _buildDetailRow('Employee Code', auth.teacherProfile!['employee_code'] ?? 'TCH-001'),
                        const Divider(height: 20, color: BeastColors.borderSubtle),
                        _buildDetailRow('Qualification', auth.teacherProfile!['qualification'] ?? 'N/A'),
                        const Divider(height: 20, color: BeastColors.borderSubtle),
                        _buildDetailRow('Specialization', auth.teacherProfile!['bio'] ?? 'N/A'),
                      ] else ...[
                        _buildDetailRow('Designation', 'Institutional Director & Administrator'),
                        const Divider(height: 20, color: BeastColors.borderSubtle),
                        _buildDetailRow('Permissions', 'Full Campus RBAC Super-Admin'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: BeastSpacing.lg),

                // Security & Privacy Settings
                Text('Security & Governance', style: BeastTypography.h3),
                const SizedBox(height: BeastSpacing.sm),
                BeastCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_reset, color: BeastColors.dark900),
                        title: Text('Change Password', style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text('Update your institutional account credentials', style: BeastTypography.caption),
                        trailing: const Icon(Icons.chevron_right, size: 20, color: BeastColors.textMuted),
                        onTap: () => _showChangePasswordDialog(context),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 1, color: BeastColors.borderSubtle),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, color: BeastColors.dark900),
                        title: Text('Privacy & Institutional Charter', style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text('Zero tracking, strict academic confidentiality', style: BeastTypography.caption),
                        trailing: const Icon(Icons.chevron_right, size: 20, color: BeastColors.textMuted),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('B.E.A.S.T ACADEMY Charter', style: BeastTypography.h3),
                              content: const Text(
                                '• Student data is never sold or shared with third parties.\n'
                                '• Zero mandatory paid SaaS or cloud tracking dependencies.\n'
                                '• Academic records and doubts remain exclusively between student and faculty.\n'
                                '• All passwords hashed with industry standard bcrypt.\n'
                                '• Relational ACID database with full RBAC enforcement.',
                                style: TextStyle(fontSize: 13, height: 1.5),
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: BeastColors.dark900),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Understood'),
                                ),
                              ],
                            ),
                          );
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BeastSpacing.xl),

                // Sign Out Button
                OutlinedButton.icon(
                  onPressed: () async {
                    await auth.logout();
                  },
                  icon: const Icon(Icons.logout, color: BeastColors.error, size: 18),
                  label: const Text('Sign Out of Academy', style: TextStyle(color: BeastColors.error, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: BeastColors.error),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BeastLogo(size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'B.E.A.S.T ACADEMY v1.0.0 • Production Release',
                        style: BeastTypography.caption.copyWith(color: BeastColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: BeastTypography.bodyMedium.copyWith(color: BeastColors.textSecondary)),
        Text(value, style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: BeastColors.dark900)),
      ],
    );
  }
}
