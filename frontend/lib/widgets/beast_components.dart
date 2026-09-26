import 'package:flutter/material.dart';
import '../core/theme/beast_tokens.dart';

// ============================================================
// 1. CARDS & CONTAINERS
// ============================================================

/// Elevated white card with subtle border and consistent spacing.
class BeastCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final double borderRadius;

  const BeastCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.boxShadow,
    this.borderRadius = BeastRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding ?? const EdgeInsets.all(BeastSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? BeastColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? BeastColors.borderSubtle,
          width: 1.0,
        ),
        boxShadow: boxShadow ?? BeastShadows.subtle,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          hoverColor: BeastColors.hover,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Actionable Card with an icon badge and chevron for jump navigation.
class BeastActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? badgeColor;

  const BeastActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return BeastCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: BeastSpacing.lg,
        vertical: BeastSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(BeastSpacing.sm + 2),
            decoration: BoxDecoration(
              color: badgeColor ?? BeastColors.surfaceWarm,
              borderRadius: BorderRadius.circular(BeastRadius.sm),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? BeastColors.brandPrimary,
            ),
          ),
          const SizedBox(width: BeastSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: BeastTypography.bodyMedium),
                Text(subtitle, style: BeastTypography.caption),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: BeastColors.textMuted,
          ),
        ],
      ),
    );
  }
}

/// Metric display card for dashboards and statistics.
class BeastStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? accentColor;
  final VoidCallback? onTap;

  const BeastStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? BeastColors.peach400;

    return BeastCard(
      onTap: onTap,
      padding: const EdgeInsets.all(BeastSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: BeastTypography.label.copyWith(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: effectiveAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(BeastRadius.xs),
                ),
                child: Icon(icon, size: 16, color: BeastColors.dark900),
              ),
            ],
          ),
          const SizedBox(height: BeastSpacing.sm),
          Text(
            value,
            style: BeastTypography.metric,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: BeastSpacing.xs),
            Text(
              subtitle!,
              style: BeastTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// 2. HEADERS & SECTION TITLES
// ============================================================

class BeastPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const BeastPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeastSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: BeastTypography.headline),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: BeastTypography.subtitle),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class BeastSectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const BeastSectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: BeastSpacing.md,
        bottom: BeastSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: BeastTypography.title.copyWith(fontSize: 16)),
          ?action,
        ],
      ),
    );
  }
}

// ============================================================
// 3. BADGES & STATUS INDICATORS
// ============================================================

enum BeastBadgeVariant { peach, neutral, warning, success, error }

class BeastBadge extends StatelessWidget {
  final String label;
  final BeastBadgeVariant? variant;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const BeastBadge({
    super.key,
    required this.label,
    this.variant,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (variant != null) {
      switch (variant!) {
        case BeastBadgeVariant.peach:
          bg = BeastColors.peach200;
          fg = BeastColors.dark900;
          break;
        case BeastBadgeVariant.neutral:
          bg = BeastColors.neutral100;
          fg = BeastColors.dark900;
          break;
        case BeastBadgeVariant.warning:
          bg = BeastColors.warningLight;
          fg = BeastColors.warning;
          break;
        case BeastBadgeVariant.success:
          bg = BeastColors.successLight;
          fg = BeastColors.success;
          break;
        case BeastBadgeVariant.error:
          bg = BeastColors.errorLight;
          fg = BeastColors.error;
          break;
      }
    } else {
      bg = backgroundColor ?? BeastColors.peach200;
      fg = textColor ?? BeastColors.dark900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BeastRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Semantic Status Badge: Combines icon + color + text for accessibility.
class BeastStatusBadge extends StatelessWidget {
  final String status;

  const BeastStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toUpperCase();

    Color bg;
    Color fg;
    IconData icon;

    switch (s) {
      case 'ACTIVE':
      case 'PRESENT':
      case 'PAID':
      case 'APPROVED':
      case 'RESOLVED':
      case 'VERIFIED':
        bg = BeastColors.successLight;
        fg = BeastColors.success;
        icon = Icons.check_circle_rounded;
        break;

      case 'PENDING':
      case 'LATE':
      case 'PENDING_REVIEW':
      case 'PENDING_TEACHER_REVIEW':
      case 'PENDING_ADMIN_REVIEW':
      case 'PENDING_SUPER_ADMIN_REVIEW':
      case 'OVERDUE':
        bg = BeastColors.warningLight;
        fg = BeastColors.warning;
        icon = Icons.schedule_rounded;
        break;

      case 'SUSPENDED':
      case 'ABSENT':
      case 'REJECTED':
      case 'ARCHIVED':
      case 'INACTIVE':
      case 'CANCELLED':
        bg = BeastColors.dangerLight;
        fg = BeastColors.danger;
        icon = Icons.cancel_rounded;
        break;

      default:
        bg = BeastColors.neutral200;
        fg = BeastColors.textSecondary;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BeastRadius.xs),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            s.replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 4. BUTTONS
// ============================================================

class BeastPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;

  const BeastPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: BeastColors.brandPrimary,
        foregroundColor: BeastColors.textOnDark,
        elevation: 0,
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeastRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(BeastColors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: BeastSpacing.sm),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
    );
  }
}

class BeastSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  const BeastSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: BeastColors.textPrimary,
        side: const BorderSide(color: BeastColors.borderStrong, width: 1.2),
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeastRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: BeastSpacing.sm),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class BeastDangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const BeastDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: BeastColors.danger,
        foregroundColor: BeastColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BeastRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: BeastSpacing.md,
          vertical: BeastSpacing.sm,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================
// 5. STATES: EMPTY, LOADING, ERROR
// ============================================================

class BeastEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? subtitle;
  final Widget? action;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  const BeastEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.subtitle,
    this.action,
    this.buttonLabel,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMessage = subtitle ?? message ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BeastSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(BeastSpacing.lg),
              decoration: const BoxDecoration(
                color: BeastColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: BeastColors.textSecondary),
            ),
            const SizedBox(height: BeastSpacing.lg),
            Text(title, style: BeastTypography.title, textAlign: TextAlign.center),
            if (effectiveMessage.isNotEmpty) ...[
              const SizedBox(height: BeastSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  effectiveMessage,
                  style: BeastTypography.body.copyWith(color: BeastColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: BeastSpacing.lg),
              action!,
            ] else if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: BeastSpacing.lg),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BeastColors.dark900,
                  foregroundColor: Colors.white,
                ),
                onPressed: onButtonPressed,
                child: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BeastErrorState extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback onRetry;

  const BeastErrorState({
    super.key,
    this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BeastSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(BeastSpacing.md),
              decoration: const BoxDecoration(
                color: BeastColors.dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 32, color: BeastColors.danger),
            ),
            const SizedBox(height: BeastSpacing.md),
            Text('Unable to load data', style: BeastTypography.title),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                style: BeastTypography.caption.copyWith(color: BeastColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: BeastSpacing.md),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BeastLoadingState extends StatelessWidget {
  final String? message;

  const BeastLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(BeastColors.brandPrimary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: BeastSpacing.md),
            Text(
              message!,
              style: BeastTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmer Skeleton Placeholder for modern loading layouts.
class BeastSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const BeastSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = BeastRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: BeastColors.neutral100,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ============================================================
// 6. CONFIRMATION DIALOG
// ============================================================

class BeastConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const BeastConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    required this.onConfirm,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => BeastConfirmDialog(
        title: title,
        content: content,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeastRadius.md),
      ),
      backgroundColor: BeastColors.white,
      title: Text(title, style: BeastTypography.title),
      content: Text(
        content,
        style: BeastTypography.body.copyWith(color: BeastColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: const TextStyle(color: BeastColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? BeastColors.danger : BeastColors.brandPrimary,
            foregroundColor: BeastColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BeastRadius.xs),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
