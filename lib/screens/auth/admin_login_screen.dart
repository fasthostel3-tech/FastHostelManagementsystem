import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../config/app_keys.dart';
import '../../services/admin_service.dart';
import '../../utils/admin_utils.dart';
import 'loading_auth_screen.dart';

/// Dedicated login screen for administrators.
///
/// Accessible at `/auth/admin-login`. The router never redirects a logged-in
/// student away from this route, so students can switch to an admin account
/// without being bounced to their own dashboard.
///
/// After sign-in the role is verified: if the account is not an admin the
/// user is immediately signed out and shown an error.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = AppKeys.scaffoldMessengerKey.currentState;
    setState(() => _loading = true);

    // Show loading overlay
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const LoadingAuthScreen(message: 'Signing in...'),
        fullscreenDialog: true,
      ));
    }

    try {
      final authNotifier = ref.read(currentUserProvider.notifier);
      await authNotifier.signIn(_emailCtrl.text.trim(), _passCtrl.text);

      if (!mounted) return;

      // ── Role guard ────────────────────────────────────────────────────────
      // signIn() fetches Firestore data synchronously before returning, so
      // the user model is available immediately.
      final userModel = ref.read(currentUserProvider).value;

      if (userModel != null && !AdminUtils.isAdmin(userModel)) {
        // Logged in but NOT an admin — sign them out and reject.
        try {
          await authNotifier.signOut();
        } catch (_) {}

        if (mounted) Navigator.of(context).pop(); // dismiss loading
        messenger?.showSnackBar(const SnackBar(
          content: Text(
            'This account does not have administrator privileges. '
            'Please use an admin account.',
          ),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 5),
        ));
        if (mounted) setState(() => _loading = false);
        _passCtrl.clear();
        return;
      }
      // ─────────────────────────────────────────────────────────────────────

      messenger?.showSnackBar(const SnackBar(
        content: Text('Welcome, Administrator!'),
        backgroundColor: AppTheme.successColor,
        duration: Duration(seconds: 3),
      ));

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.of(context).pop(); // dismiss loading
      // Router will redirect to /admin/dashboard automatically.
    } catch (e) {
      if (mounted) Navigator.of(context).pop();

      String msg = e.toString().replaceFirst('Exception: ', '');
      final code = RegExp(r'Sign in failed:\s*(.+)').firstMatch(msg)?.group(1)?.trim() ?? '';

      if (code == 'user-not-found' || msg.contains('user-not-found')) {
        msg = 'No admin account found with this email.';
      } else if (code == 'wrong-password' ||
          code == 'invalid-credential' ||
          msg.contains('wrong-password') ||
          msg.contains('invalid-credential')) {
        msg = 'Incorrect email or password.';
      } else if (code == 'too-many-requests') {
        msg = 'Too many attempts. Please try again later.';
      } else if (msg.contains('network') || msg.contains('unavailable')) {
        msg = 'Network error. Check your internet connection.';
      } else {
        msg = code.isNotEmpty ? 'Login failed: $code' : 'Login failed. Please try again.';
      }

      messenger?.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Dark navy header band ─────────────────────────────────────────
          _AdminHeader(onBack: () => context.go('/')),

          // ── Form ──────────────────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 36,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Title
                            Text(
                              'Administration Login',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Enter your admin credentials to access the portal',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Email field
                            _FieldLabel(label: 'Admin Email'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'admin@example.com',
                                prefixIcon: const Icon(Icons.email_outlined),
                                suffixIcon: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: AppColors.accent,
                                  size: 18,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your admin email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Use your administrator email address',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Password field
                            _FieldLabel(label: 'Password'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            // Sign-in button
                            _SignInButton(loading: _loading, onTap: _loading ? null : _login),

                            const SizedBox(height: 20),

                            // Back to student login
                            Center(
                              child: TextButton.icon(
                                onPressed: () => context.go('/auth/login'),
                                icon: const Icon(Icons.school_rounded, size: 16),
                                label: const Text('Student Login instead'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 28,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Back row
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Shield icon with glow
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              size: 36,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Administration Portal',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'FAST Hostel · NUCES Chiniot-Faisalabad Campus',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _SignInButton extends StatefulWidget {
  const _SignInButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover;

  @override
  void initState() {
    super.initState();
    _hover = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.loading
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => _hover.forward(),
      onExit: (_) => _hover.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hover,
          builder: (_, __) {
            final t = _hover.value;
            return Transform.translate(
              offset: Offset(0, -2 * t),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.loading
                        ? [
                            AppColors.primary.withValues(alpha: 0.5),
                            AppColors.primaryLight.withValues(alpha: 0.5),
                          ]
                        : [
                            Color.lerp(AppColors.primaryDark, AppColors.primary, t)!,
                            Color.lerp(AppColors.primary, AppColors.primaryLight, t)!,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: widget.loading
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: 0.22 + 0.18 * t),
                            blurRadius: 10 + 12 * t,
                            offset: Offset(0, 4 + 2 * t),
                          ),
                        ],
                ),
                child: Center(
                  child: widget.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_open_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Login as Administrator',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
