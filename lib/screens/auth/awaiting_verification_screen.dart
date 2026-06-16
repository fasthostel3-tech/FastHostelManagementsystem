import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// authService methods are accessed via authServiceProvider in providers
import '../../providers/auth_provider.dart';

class AwaitingVerificationScreen extends ConsumerStatefulWidget {
  const AwaitingVerificationScreen({super.key});

  @override
  ConsumerState<AwaitingVerificationScreen> createState() => _AwaitingVerificationScreenState();
}

class _AwaitingVerificationScreenState extends ConsumerState<AwaitingVerificationScreen> {
  Timer? _pollTimer;
  bool _isSending = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Start polling every 6 seconds to see if the user verified their email
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _checkVerified());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    try {
      if (!mounted) return;
      final authService = ref.read(authServiceProvider);
      final verified = await authService.isEmailVerified();
      if (!mounted) return;
      
      if (verified) {
        // If verified, refresh user info and navigate to the appropriate dashboard
        final current = ref.read(currentUserProvider).when(
          data: (u) => u,
          loading: () => null,
          error: (_, __) => null,
        );

        // Attempt to fetch latest user model from Firestore
        if (current != null && mounted) {
          try {
            final userModel = await ref.read(authServiceProvider).getUser(current.uid);
            _pollTimer?.cancel();
            if (mounted) {
              if (userModel != null && userModel.email.contains('admin')) {
                context.go('/admin/dashboard');
              } else {
                context.go('/student/dashboard');
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email verified — welcome!')),
              );
            }
          } catch (_) {
            // If fetching user model fails, fallback to login screen
            _pollTimer?.cancel();
            if (mounted) context.go('/auth/login');
          }
        } else {
          _pollTimer?.cancel();
          if (mounted) context.go('/auth/login');
        }
      }
    } catch (e) {
      // ignore errors during polling
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isSending = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email resent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to resend: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'A verification link has been sent to your email address.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (user != null)
              Text(
                'Email: ${user.email}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            const Text('Steps:'),
            const SizedBox(height: 8),
            const Text('1. Open your email and click the verification link.'),
            const Text('2. Come back and tap "I have verified" or wait — we will detect it automatically.'),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _isSending ? null : _resend,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: _isSending
                      ? Theme.of(context).primaryColor.withOpacity(0.5)
                      : Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: _isSending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Resend Verification Email',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _checking ? null : _checkVerified,
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _checking
                        ? Theme.of(context).primaryColor.withOpacity(0.5)
                        : Theme.of(context).primaryColor,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: _checking
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).primaryColor,
                        ),
                      )
                    : Text(
                        'I have verified',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                // Cancel and go back to login
                final authService = ref.read(authServiceProvider);
                try {
                  await authService.signOut();
                } catch (_) {}
                if (mounted) {
                  context.go('/auth/login');
                }
              },
              child: Center(
                child: Text(
                  'Back to Login',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Spacer(),
            Text(
              'We will automatically check verification periodically.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
