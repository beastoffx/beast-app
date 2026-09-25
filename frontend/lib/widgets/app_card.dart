import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: border ?? Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.present() => const StatusBadge(
        label: 'Present',
        backgroundColor: AppColors.successLight,
        textColor: AppColors.success,
        icon: Icons.check_circle_outline,
      );

  factory StatusBadge.late() => const StatusBadge(
        label: 'Late',
        backgroundColor: AppColors.warningLight,
        textColor: AppColors.warning,
        icon: Icons.schedule,
      );

  factory StatusBadge.absent() => const StatusBadge(
        label: 'Absent',
        backgroundColor: AppColors.errorLight,
        textColor: AppColors.error,
        icon: Icons.cancel_outlined,
      );

  factory StatusBadge.submitted() => const StatusBadge(
        label: 'Submitted',
        backgroundColor: AppColors.infoLight,
        textColor: AppColors.info,
        icon: Icons.upload_file,
      );

  factory StatusBadge.reviewed() => const StatusBadge(
        label: 'Reviewed',
        backgroundColor: AppColors.successLight,
        textColor: AppColors.success,
        icon: Icons.verified_outlined,
      );

  factory StatusBadge.paid() => const StatusBadge(
        label: 'Paid',
        backgroundColor: AppColors.successLight,
        textColor: AppColors.success,
        icon: Icons.check_circle,
      );

  factory StatusBadge.pending() => const StatusBadge(
        label: 'Pending',
        backgroundColor: AppColors.warningLight,
        textColor: AppColors.warning,
        icon: Icons.hourglass_empty,
      );

  factory StatusBadge.resolved() => const StatusBadge(
        label: 'Resolved',
        backgroundColor: AppColors.successLight,
        textColor: AppColors.success,
        icon: Icons.done_all,
      );

  factory StatusBadge.open() => const StatusBadge(
        label: 'Open',
        backgroundColor: AppColors.infoLight,
        textColor: AppColors.info,
        icon: Icons.chat_bubble_outline,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Compliant with Section 40: WHAT, WHY, NEXT ACTION
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Compliant with Section 41: Human-readable error states
class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 44, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(140, 42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
