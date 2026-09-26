import 'package:flutter/material.dart';
import '../core/theme/beast_tokens.dart';

/// B.E.A.S.T ACADEMY Official Emblem & Wordmark Component
/// Always uses the real official brand icon asset located at assets/icon/app_icon.png.
class BeastLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool showSubtitle;
  final Color? wordmarkColor;
  final double borderRadius;

  const BeastLogo({
    super.key,
    this.size = 48.0,
    this.showWordmark = false,
    this.showSubtitle = false,
    this.wordmarkColor,
    this.borderRadius = BeastRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BeastColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: BeastShadows.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Graceful fallback during tests or headless builds
          return Container(
            color: BeastColors.brandPrimary,
            child: Center(
              child: Text(
                'B',
                style: TextStyle(
                  color: BeastColors.peach400,
                  fontSize: size * 0.55,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );

    if (!showWordmark) {
      return imageWidget;
    }

    final textColor = wordmarkColor ?? BeastColors.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        imageWidget,
        const SizedBox(width: BeastSpacing.md),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'B.E.A.S.T ACADEMY',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: size * 0.38 > 15 ? size * 0.38 : 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: textColor,
                  height: 1.1,
                ),
              ),
              if (showSubtitle) ...[
                const SizedBox(height: 3),
                Text(
                  'Unified Academic Platform',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: BeastColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
