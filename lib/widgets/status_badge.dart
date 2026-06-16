import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// Semantic status types for UI badges.
enum StatusType { success, warning, error, info }

/// A pill-shaped status badge with semantic coloring.
///
/// Usage:
/// ```dart
/// StatusBadge(label: 'Pending', type: StatusType.warning)
/// StatusBadge(label: 'Resolved', type: StatusType.success)
/// ```
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
  });

  final String label;
  final StatusType type;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForType(context, type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.foreground,
              fontSize: 11,
            ),
      ),
    );
  }

  _BadgeColors _colorsForType(BuildContext context, StatusType type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case StatusType.success:
        return _BadgeColors(
          foreground: AppColors.success,
          background: isDark ? AppColors.success.withValues(alpha: 0.15) : const Color(0xFFDCFCE7),
        );
      case StatusType.warning:
        return _BadgeColors(
          foreground: AppColors.warning,
          background: isDark ? AppColors.warning.withValues(alpha: 0.15) : const Color(0xFFFEF3C7),
        );
      case StatusType.error:
        return _BadgeColors(
          foreground: AppColors.error,
          background: isDark ? AppColors.error.withValues(alpha: 0.15) : const Color(0xFFFEE2E2),
        );
      case StatusType.info:
        return _BadgeColors(
          foreground: AppColors.info,
          background: isDark ? AppColors.info.withValues(alpha: 0.15) : const Color(0xFFDBEAFE),
        );
    }
  }
}

class _BadgeColors {
  const _BadgeColors({required this.foreground, required this.background});
  final Color foreground;
  final Color background;
}
