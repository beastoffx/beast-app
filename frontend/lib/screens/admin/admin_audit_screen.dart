import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/beast_components.dart';

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAuditLogs();
    });
  }

  void _showLogDetail(BuildContext context, dynamic log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(log['action'] ?? 'Audit Event', style: BeastTypography.h3),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Entity: ${(log['entity_type'] ?? 'system').toUpperCase()}', style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              Text('Actor: ${log['user_name'] ?? "System"} (${log['user_email'] ?? "internal"})', style: BeastTypography.caption),
              Text('Timestamp: ${log['created_at']}', style: BeastTypography.caption),
              Text('IP Address: ${log['ip_address'] ?? "local"}', style: BeastTypography.caption),
              const SizedBox(height: 14),
              const Text('Payload Details:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeastColors.neutral100,
                  borderRadius: BorderRadius.circular(BeastRadius.sm),
                  border: Border.all(color: BeastColors.borderSubtle),
                ),
                child: Text(
                  log['details_json']?.toString() ?? 'No extra parameters.',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text('Administrative Audit Ledger', style: BeastTypography.h3),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BeastColors.dark900),
            onPressed: () => admin.fetchAuditLogs(),
          ),
        ],
      ),
      body: admin.isLoading
          ? const Center(child: BeastLoadingState(message: 'Loading forensic audit trail...'))
          : admin.auditLogs.isEmpty
              ? const BeastEmptyState(
                  icon: Icons.security_outlined,
                  title: 'Audit Log Empty',
                  subtitle: 'All sensitive system actions, logins, grading, and attendance modifications will be recorded here.',
                )
              : RefreshIndicator(
                  onRefresh: () => admin.fetchAuditLogs(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(BeastSpacing.lg),
                    itemCount: admin.auditLogs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                    itemBuilder: (ctx, i) {
                      final log = admin.auditLogs[i];
                      return InkWell(
                        onTap: () => _showLogDetail(context, log),
                        borderRadius: BorderRadius.circular(BeastRadius.md),
                        child: BeastCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: BeastColors.peach200,
                                  borderRadius: BorderRadius.circular(BeastRadius.sm),
                                ),
                                child: const Icon(Icons.shield_outlined, size: 20, color: BeastColors.dark900),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          log['action'] ?? 'ACTION',
                                          style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        BeastBadge(
                                          label: (log['entity_type'] ?? 'system').toUpperCase(),
                                          variant: BeastBadgeVariant.neutral,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Actor: ${log['user_name'] ?? "System"} (${log['user_email'] ?? "internal"})',
                                      style: BeastTypography.caption,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Time: ${log['created_at']} • IP: ${log['ip_address'] ?? "local"}',
                                      style: BeastTypography.caption.copyWith(color: BeastColors.textMuted),
                                    ),
                                    if (log['details_json'] != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        '${log['details_json']}',
                                        style: BeastTypography.caption.copyWith(fontStyle: FontStyle.italic),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
