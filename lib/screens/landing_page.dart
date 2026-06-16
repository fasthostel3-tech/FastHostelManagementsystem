import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../utils/admin_utils.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FAST Hostel — Landing Page
//  A robust, responsive, animated marketing page. Entrance animations always
//  complete (no scroll dependency), so content can never be left invisible.
// ════════════════════════════════════════════════════════════════════════════

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  final ScrollController _scroll = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = _scroll.offset > 12;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                _Hero(isWide: isWide),
                _FeaturesSection(isWide: isWide),
                _StepsSection(isWide: isWide),
                _AdminSection(isWide: isWide),
                _StatsBand(isWide: isWide),
                _CtaSection(isWide: isWide),
                const _Footer(),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _NavBar(scrolled: _scrolled, isWide: isWide),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Entrance animation — always completes, never leaves content hidden.
// ════════════════════════════════════════════════════════════════════════════

class _FadeInUp extends StatelessWidget {
  const _FadeInUp({
    required this.child,
    this.delayMs = 0,
  });
  final Widget child;
  final int delayMs;
  static const double offsetY = 28;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        // First portion of the timeline acts as the "delay" (no visible motion).
        final span = 700 / (700 + delayMs);
        final start = 1 - span;
        final p = ((t - start) / span).clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, offsetY * (1 - p)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Navigation bar
// ════════════════════════════════════════════════════════════════════════════

class _NavBar extends ConsumerWidget {
  const _NavBar({required this.scrolled, required this.isWide});
  final bool scrolled;
  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userModel = ref.watch(currentUserProvider).value;
    final isLoggedIn = userModel != null;
    final isAdmin = AdminUtils.isAdmin(userModel);
    final dashRoute = isAdmin ? '/admin/dashboard' : '/student/dashboard';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 16),
      decoration: BoxDecoration(
        color: scrolled ? AppColors.primary : Colors.transparent,
        boxShadow: scrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          _Logo(isWide: isWide),
          const Spacer(),
          if (isLoggedIn)
            _NavBtn(
              label: 'Go to Dashboard',
              icon: Icons.dashboard_rounded,
              filled: true,
              onTap: () => context.go(dashRoute),
            )
          else ...[
            if (isWide) ...[
              _NavBtn(
                label: 'Administration',
                icon: Icons.lock_outline_rounded,
                outlined: true,
                accent: true,
                onTap: () => context.go('/auth/admin-login'),
              ),
              const SizedBox(width: 10),
            ],
            _NavBtn(
              label: 'Sign In',
              outlined: true,
              onTap: () => context.go('/auth/login'),
            ),
            const SizedBox(width: 10),
            _NavBtn(
              label: 'Get Started',
              filled: true,
              onTap: () => context.go('/auth/signup'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            'assets/images/fast_logo-removebg-preview.png',
            width: 38,
            height: 38,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAST Hostel',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
            if (isWide)
              Text(
                'NUCES Chiniot-Faisalabad Campus',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 1.0,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _NavBtn extends StatefulWidget {
  const _NavBtn({
    required this.label,
    required this.onTap,
    this.icon,
    this.outlined = false,
    this.filled = false,
    this.accent = false,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool outlined;
  final bool filled;
  final bool accent;

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.accent;
    final Color bg;
    final Color fg;
    final Border? border;

    if (widget.filled) {
      bg = _hover ? const Color(0xFFE3B226) : gold;
      fg = AppColors.primary;
      border = null;
    } else {
      final base = widget.accent ? gold : Colors.white;
      bg = _hover ? base.withValues(alpha: 0.14) : Colors.transparent;
      fg = base;
      border = Border.all(color: base.withValues(alpha: 0.6));
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: border,
            boxShadow: widget.filled && _hover
                ? [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 15, color: fg),
                const SizedBox(width: 7),
              ],
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Hero
// ════════════════════════════════════════════════════════════════════════════

class _Hero extends StatefulWidget {
  const _Hero({required this.isWide});
  final bool isWide;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with TickerProviderStateMixin {
  late final AnimationController _orbs;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _orbs =
        AnimationController(vsync: this, duration: const Duration(seconds: 11))
          ..repeat(reverse: true);
    _float = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbs.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = widget.isWide;
    final screenH = MediaQuery.of(context).size.height;
    // Guaranteed minimum height so the hero always renders (never collapses).
    final minH = math.max(screenH, 640.0);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minH),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            Color(0xFF1B3B73),
            AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative layers
          Positioned.fill(
            child: CustomPaint(painter: _DotGrid(Colors.white, 0.035)),
          ),
          AnimatedBuilder(
            animation: _orbs,
            builder: (_, __) {
              final t = _orbs.value;
              return Positioned.fill(
                child: Stack(
                  children: [
                    Positioned(
                      top: -90 + 60 * t,
                      right: -70 + 45 * t,
                      child: _Orb(
                          size: isWide ? 440 : 250,
                          color: AppColors.accent.withValues(alpha: 0.14)),
                    ),
                    Positioned(
                      bottom: -130 + 70 * (1 - t),
                      left: -90 + 55 * t,
                      child: _Orb(
                          size: isWide ? 500 : 300,
                          color:
                              AppColors.primaryLight.withValues(alpha: 0.25)),
                    ),
                    Positioned(
                      top: 120 + 30 * (1 - t),
                      left: isWide ? 120 : 24,
                      child: _Orb(
                          size: 90,
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                  ],
                ),
              );
            },
          ),
          // Content — a non-positioned child so the Stack sizes correctly.
          Padding(
            padding: EdgeInsets.fromLTRB(
              isWide ? 64 : 24,
              110,
              isWide ? 64 : 24,
              72,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _FadeInUp(child: _PulsingLogo(isWide: isWide)),
                    const SizedBox(height: 28),
                    const _FadeInUp(
                      delayMs: 80,
                      child: _BadgePill(
                          label: 'Official NUCES Hostel Management System'),
                    ),
                    const SizedBox(height: 26),
                    _FadeInUp(
                      delayMs: 160,
                      child: Text(
                        'Campus Living,',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: isWide ? 62 : 40,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.05,
                        ),
                      ),
                    ),
                    _FadeInUp(
                      delayMs: 220,
                      child: ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [AppColors.accent, Color(0xFFF5C842)],
                        ).createShader(b),
                        child: Text(
                          'Reimagined.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isWide ? 62 : 40,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _FadeInUp(
                      delayMs: 300,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Text(
                          'The complete digital platform for FAST-NUCES hostel life — '
                          'apply for accommodation, choose your room, manage mess '
                          'attendance and pay your bills, all in one place.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: isWide ? 16 : 14,
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.75,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _FadeInUp(
                      delayMs: 380,
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _HeroBtn(
                            label: 'Apply for Hostel',
                            primary: true,
                            icon: Icons.lock_outline_rounded,
                            onTap: () => context.go('/auth/signup'),
                          ),
                          _HeroBtn(
                            label: 'Student Sign In',
                            primary: false,
                            icon: Icons.lock_outline_rounded,
                            onTap: () => context.go('/auth/login'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 38),
                    _FadeInUp(
                      delayMs: 460,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _StatChip(
                              icon: Icons.bed_rounded,
                              label: '300+ Beds',
                              ctrl: _float,
                              phase: 0.0),
                          _StatChip(
                              icon: Icons.home_work_rounded,
                              label: '2 Halls',
                              ctrl: _float,
                              phase: 0.33),
                          _StatChip(
                              icon: Icons.restaurant_rounded,
                              label: '3 Meals Daily',
                              ctrl: _float,
                              phase: 0.66),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingLogo extends StatefulWidget {
  const _PulsingLogo({required this.isWide});
  final bool isWide;

  @override
  State<_PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<_PulsingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.isWide ? 104.0 : 80.0;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = _pulse.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size + 46 + 16 * t,
              height: size + 46 + 16 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent
                      .withValues(alpha: 0.08 + 0.06 * (1 - t)),
                  width: 1.5,
                ),
              ),
            ),
            Container(
              width: size + 26 + 10 * t,
              height: size + 26 + 10 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent
                      .withValues(alpha: 0.14 + 0.08 * (1 - t)),
                  width: 1.5,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        AppColors.accent.withValues(alpha: 0.28 + 0.16 * t),
                    blurRadius: 34 + 20 * t,
                    spreadRadius: 2 + 4 * t,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/fast_logo-removebg-preview.png',
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: AppColors.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.ctrl,
    required this.phase,
  });
  final IconData icon;
  final String label;
  final AnimationController ctrl;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = (ctrl.value + phase) % 1.0;
        final dy = math.sin(t * math.pi * 2) * 5.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: AppColors.accent),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroBtn extends StatefulWidget {
  const _HeroBtn(
      {required this.label,
      required this.primary,
      required this.onTap,
      this.icon});
  final String label;
  final bool primary;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_HeroBtn> createState() => _HeroBtnState();
}

class _HeroBtnState extends State<_HeroBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 17),
          decoration: BoxDecoration(
            color: widget.primary
                ? (_hover ? const Color(0xFFE3B226) : AppColors.accent)
                : Colors.white.withValues(alpha: _hover ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(12),
            border: widget.primary
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.55)),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: AppColors.accent
                          .withValues(alpha: _hover ? 0.5 : 0.3),
                      blurRadius: _hover ? 26 : 14,
                      offset: Offset(0, _hover ? 10 : 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.primary ? AppColors.primary : Colors.white,
                ),
                const SizedBox(width: 9),
              ],
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.primary ? AppColors.primary : Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Features
// ════════════════════════════════════════════════════════════════════════════

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({required this.isWide});
  final bool isWide;

  static const _features = [
    (Icons.home_work_rounded, 'Hostel Allotment',
        'Submit your application online with room-type preferences and digital document upload.'),
    (Icons.bed_rounded, 'Room Selection',
        'Browse halls, floors and rooms in real time and pick the bed that suits you best.'),
    (Icons.restaurant_rounded, 'Mess Management',
        'View weekly menus, mark meal attendance and track your mess bill transparently.'),
    (Icons.fitness_center_rounded, 'Gym Membership',
        'Register for campus gym access with annual membership and digital fee challans.'),
    (Icons.payments_rounded, 'Digital Payments',
        'Generated challans, proof uploads and admin verification — no paper trail needed.'),
    (Icons.campaign_rounded, 'Notices & Support',
        'Stay informed with the notice board and raise complaints that reach admins instantly.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceAlt,
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: isWide ? 90 : 64),
      child: Column(
        children: [
          const _FadeInUp(
            child: _SectionHead(
              badge: 'STUDENT FEATURES',
              badgeColor: AppColors.primary,
              title: 'Everything Under One Roof',
              subtitle:
                  'Six integrated modules covering every part of residential campus life.',
            ),
          ),
          const SizedBox(height: 50),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < _features.length; i++)
                  _FadeInUp(
                    delayMs: 60 * i,
                    child: _FeatureCard(
                      icon: _features[i].$1,
                      title: _features[i].$2,
                      body: _features[i].$3,
                      width: isWide ? 348 : double.infinity,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.width,
  });
  final IconData icon;
  final String title;
  final String body;
  final double width;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        transform: Matrix4.translationValues(0, _hover ? -8 : 0, 0),
        width: widget.width,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hover ? AppColors.accent : AppColors.divider,
            width: _hover ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  AppColors.primary.withValues(alpha: _hover ? 0.16 : 0.05),
              blurRadius: _hover ? 30 : 14,
              offset: Offset(0, _hover ? 14 : 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _hover
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.icon,
                size: 26,
                color: _hover ? AppColors.accent : AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.body,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.65,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  How it works — steps
// ════════════════════════════════════════════════════════════════════════════

class _StepsSection extends StatelessWidget {
  const _StepsSection({required this.isWide});
  final bool isWide;

  static const _steps = [
    ('01', 'Create Account',
        'Sign up with your university email and complete your student profile.'),
    ('02', 'Apply Online',
        'Choose your preferred room type and submit the hostel application.'),
    ('03', 'Pay the Fee',
        'Download the generated challan, pay at the bank and upload proof.'),
    ('04', 'Move In',
        'Select your room once verified — your bed is reserved instantly.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: isWide ? 90 : 64),
      child: Column(
        children: [
          const _FadeInUp(
            child: _SectionHead(
              badge: 'HOW IT WORKS',
              badgeColor: AppColors.accent,
              title: 'From Application to Allotment',
              subtitle: 'Four simple steps to your hostel room.',
            ),
          ),
          const SizedBox(height: 50),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Wrap(
              spacing: 22,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  _FadeInUp(
                    delayMs: 80 * i,
                    child: _StepCard(
                      number: _steps[i].$1,
                      title: _steps[i].$2,
                      body: _steps[i].$3,
                      width: isWide ? 262 : double.infinity,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
    required this.width,
  });
  final String number;
  final String title;
  final String body;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ).createShader(b),
            child: Text(
              number,
              style: GoogleFonts.playfairDisplay(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Admin section (dark)
// ════════════════════════════════════════════════════════════════════════════

class _AdminSection extends StatelessWidget {
  const _AdminSection({required this.isWide});
  final bool isWide;

  static const _caps = [
    (Icons.assignment_turned_in_rounded, 'Application Management',
        'Review, approve or reject hostel applications with a full audit trail.'),
    (Icons.analytics_rounded, 'Live Analytics',
        'Real-time occupancy dashboard, application pipeline and visual charts.'),
    (Icons.receipt_long_rounded, 'Fee & Challan Tracking',
        'Generate challans, verify bank uploads and track payment status.'),
    (Icons.campaign_rounded, 'Notices & Alerts',
        'Broadcast important announcements to all residents instantly.'),
    (Icons.restaurant_menu_rounded, 'Mess & Gym Oversight',
        'Manage meal schedules, mark attendance and gym memberships.'),
    (Icons.meeting_room_rounded, 'Hall & Room Control',
        'Configure hostels, halls, room capacities and assignments.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071224), AppColors.primary, Color(0xFF0C1D3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DotGrid(Colors.white, 0.022)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isWide ? 64 : 20, vertical: isWide ? 90 : 64),
            child: Column(
              children: [
                const _FadeInUp(
                  child: _SectionHead(
                    badge: 'FOR ADMINISTRATORS',
                    badgeColor: AppColors.accent,
                    title: 'Powerful Administration Portal',
                    subtitle:
                        'A comprehensive control panel to manage every aspect of campus residential life.',
                    dark: true,
                  ),
                ),
                const SizedBox(height: 50),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < _caps.length; i++)
                        _FadeInUp(
                          delayMs: 60 * i,
                          child: _AdminCard(
                            icon: _caps[i].$1,
                            title: _caps[i].$2,
                            body: _caps[i].$3,
                            width: isWide ? 290 : double.infinity,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 44),
                _FadeInUp(
                  delayMs: 200,
                  child: _HeroBtn(
                    label: 'Login to Administration',
                    primary: true,
                    icon: Icons.lock_outline_rounded,
                    onTap: () => context.go('/auth/admin-login'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Authorized personnel only · Login required',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatefulWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.width,
  });
  final IconData icon;
  final String title;
  final String body;
  final double width;

  @override
  State<_AdminCard> createState() => _AdminCardState();
}

class _AdminCardState extends State<_AdminCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
        width: widget.width,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _hover ? 0.11 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hover
                ? AppColors.accent.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, size: 22, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.body,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Stats band
// ════════════════════════════════════════════════════════════════════════════

class _StatsBand extends StatelessWidget {
  const _StatsBand({required this.isWide});
  final bool isWide;

  static const _stats = [
    ('300+', 'Beds Available'),
    ('2', 'Residential Halls'),
    ('6', 'Integrated Modules'),
    ('24/7', 'Online Access'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceAlt,
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: isWide ? 56 : 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Wrap(
            spacing: isWide ? 70 : 36,
            runSpacing: 28,
            alignment: WrapAlignment.center,
            children: [
              for (final s in _stats)
                _FadeInUp(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ).createShader(b),
                        child: Text(
                          s.$1,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isWide ? 46 : 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.$2,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CTA
// ════════════════════════════════════════════════════════════════════════════

class _CtaSection extends ConsumerWidget {
  const _CtaSection({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(currentUserProvider).value != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 64 : 20, vertical: isWide ? 90 : 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        children: [
          _FadeInUp(
            child: Text(
              'Ready to Move In?',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: isWide ? 40 : 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _FadeInUp(
            delayMs: 80,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Create your account today and secure your spot in the FAST-NUCES hostel.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.7,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _FadeInUp(
            delayMs: 160,
            child: _HeroBtn(
              label: isLoggedIn ? 'Go to Dashboard' : 'Get Started Now',
              primary: true,
              onTap: () => context
                  .go(isLoggedIn ? '/student/dashboard' : '/auth/signup'),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Footer
// ════════════════════════════════════════════════════════════════════════════

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryDark,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Image.asset(
                  'assets/images/fast_logo-removebg-preview.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'FAST Hostel',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'National University of Computer and Emerging Sciences · Chiniot-Faisalabad Campus',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} FAST-NUCES. All rights reserved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Shared helpers
// ════════════════════════════════════════════════════════════════════════════

class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
    this.dark = false,
  });
  final String badge;
  final Color badgeColor;
  final String title;
  final String subtitle;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: (dark ? AppColors.accent : badgeColor)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: (dark ? AppColors.accent : badgeColor)
                    .withValues(alpha: 0.3)),
          ),
          child: Text(
            badge,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: dark ? AppColors.accent : badgeColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: isWide ? 38 : 28,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white : AppColors.primary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 64,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: dark
                  ? Colors.white.withValues(alpha: 0.62)
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _DotGrid extends CustomPainter {
  const _DotGrid(this.color, this.opacity);
  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withValues(alpha: opacity);
    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGrid old) => false;
}
