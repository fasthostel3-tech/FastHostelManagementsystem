import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';

/// Premium UI kit — shared motion + surface components used across the app.
/// Keep this dependency-free (no Riverpod / Firebase) so any screen can use it.

// ── Hover lift card ───────────────────────────────────────────────────────────
/// Wraps [child] in a surface that lifts 4px with a deepened shadow on hover
/// (desktop/web) and provides an ink ripple on tap.
class HoverLiftCard extends StatefulWidget {
  const HoverLiftCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16,
    this.color,
    this.border,
    this.hoverBorderColor,
    this.padding,
    this.liftHeight = 4,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? color;
  final BoxBorder? border;
  final Color? hoverBorderColor;
  final EdgeInsetsGeometry? padding;
  final double liftHeight;

  @override
  State<HoverLiftCard> createState() => _HoverLiftCardState();
}

class _HoverLiftCardState extends State<HoverLiftCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(0.0, _hovered ? -widget.liftHeight : 0.0),
        decoration: BoxDecoration(
          color: widget.color ??
              (isDark ? const Color(0xFF1A2540) : Colors.white),
          borderRadius: radius,
          border: _hovered && widget.hoverBorderColor != null
              ? Border.all(color: widget.hoverBorderColor!, width: 1.4)
              : widget.border,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary
                  .withValues(alpha: _hovered ? 0.16 : 0.06),
              blurRadius: _hovered ? 26 : 10,
              offset: Offset(0, _hovered ? 12 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Staggered entrance ────────────────────────────────────────────────────────
/// Fades + slides [child] in after `60ms * index`, producing the staggered
/// cascade used on dashboards and lists.
class StaggeredEntry extends StatefulWidget {
  const StaggeredEntry({
    super.key,
    required this.index,
    required this.child,
    this.baseDelayMs = 60,
  });

  final int index;
  final Widget child;
  final int baseDelayMs;

  @override
  State<StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    Future.delayed(Duration(milliseconds: widget.baseDelayMs * widget.index),
        () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.10),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Animated counter ──────────────────────────────────────────────────────────
/// Counts from 0 to [value] on first build. Optional [prefix]/[suffix] and
/// thousands separators for currency display.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
    this.useGrouping = true,
  });

  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final bool useGrouping;

  @override
  Widget build(BuildContext context) {
    final fmt = useGrouping ? NumberFormat('#,##0', 'en_US') : null;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text =
            fmt != null ? fmt.format(v) : v.toStringAsFixed(0);
        return Text('$prefix$text$suffix',
            style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
      },
    );
  }
}

// ── Gradient primary button ───────────────────────────────────────────────────
/// 48px-tall primary action button with navy gradient, hover glow and ripple.
class AppGradientButton extends StatefulWidget {
  const AppGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  State<AppGradientButton> createState() => _AppGradientButtonState();
}

class _AppGradientButtonState extends State<AppGradientButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        width: widget.expand ? double.infinity : null,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? [AppColors.primary, AppColors.primaryLight]
                : [
                    AppColors.primary.withValues(alpha: 0.5),
                    AppColors.primaryLight.withValues(alpha: 0.5),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary
                        .withValues(alpha: _hovered ? 0.45 : 0.22),
                    blurRadius: _hovered ? 22 : 10,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? widget.onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────
/// Consistent rounded status chip used in tables, lists and detail views.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
/// Gold accent bar + title — the canonical section divider across the app.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
