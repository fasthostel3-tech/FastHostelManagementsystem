import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../config/app_keys.dart';
import '../../services/admin_service.dart';
import 'loading_auth_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _passwordEdited = false;
  bool _fieldsInitialized = false;
  // Real-time domain validation
  String? _emailDomainError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_handlePasswordChanged);
    _emailController.addListener(_validateEmailDomain);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fieldsInitialized) {
      _resetInputFields(clearEmail: true);
      _fieldsInitialized = true;
    }
  }

  void _handlePasswordChanged() {
    if (!_passwordEdited && _passwordController.text.isNotEmpty) {
      _passwordEdited = true;
    }
  }

  void _resetInputFields({bool clearEmail = false}) {
    if (!mounted) return;
    if (clearEmail && _emailController.hasListeners) {
      _emailController.clear();
    }
    if (_passwordController.hasListeners) {
      _passwordController.clear();
    }
    _passwordEdited = false;
  }

  @override
  void dispose() {
    _passwordController.removeListener(_handlePasswordChanged);
    _emailController.removeListener(_validateEmailDomain);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateEmailDomain() {
    final value = _emailController.text.trim().toLowerCase();
    if (value.isEmpty) {
      if (_emailDomainError != null) setState(() => _emailDomainError = null);
      return;
    }
    // Only show domain error if user has typed an @ sign (otherwise it's still being typed)
    if (!value.contains('@')) {
      if (_emailDomainError != null) setState(() => _emailDomainError = null);
      return;
    }
    final isValidDomain = value.endsWith('@cfd.nu.edu.pk') ||
        AdminService.isApprovedAdminEmail(_emailController.text.trim());
    final newError = isValidDomain
        ? null
        : 'Use your @cfd.nu.edu.pk email or an admin email';
    if (newError != _emailDomainError) {
      setState(() => _emailDomainError = newError);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = AppKeys.scaffoldMessengerKey.currentState;

    if (!_passwordEdited || _passwordController.text.trim().isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Please enter your password to continue.'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoadingAuthScreen(message: 'Signing in...'),
          fullscreenDialog: true,
        ),
      );
    }

    try {
      debugPrint('Starting login process...');
      final authNotifier = ref.read(currentUserProvider.notifier);

      debugPrint('Calling authNotifier.signIn...');
      await authNotifier.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      debugPrint('authNotifier.signIn completed');

      if (!mounted) {
        debugPrint('Login screen disposed after signIn; aborting post-login flow.');
        return;
      }

      debugPrint('Checking Firebase Auth state...');

      final authService = ref.read(authServiceProvider);
      var authUser = authService.currentUser;

      if (authUser != null) {
        try {
          await authUser.reload();
          authUser = authService.currentUser;
        } catch (e) {
          debugPrint('Warning: Failed to reload user: $e');
        }
      }

      if (authUser == null) {
        debugPrint('Error: Firebase Auth user is null after login');
        if (mounted) Navigator.of(context).pop();
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Login failed. Please check your credentials and try again.'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      debugPrint('Login successful - Firebase Auth user: ${authUser.email}, UID: ${authUser.uid}');

      if (!mounted) {
        debugPrint('Login screen disposed before reading user provider; aborting SnackBar.');
        return;
      }

      final currentUserAsync = ref.read(currentUserProvider);
      final userModel = currentUserAsync.value;

      debugPrint('Current user state: ${currentUserAsync.runtimeType}, userModel: ${userModel?.email ?? "null"}');

      if (userModel == null) {
        debugPrint('Warning: User document not found in Firestore for UID: ${authUser.uid}. Proceeding with Firebase Auth only.');
        if (mounted) Navigator.of(context).pop();
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Login successful! Some profile features may be limited.'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Login successful! Welcome back.'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 3),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute == '/auth/login' || currentRoute == null) {
          Navigator.of(context).pop();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Login error caught: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) Navigator.of(context).pop();

      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      String errorCode = '';

      if (errorMessage.contains('Sign in failed:')) {
        final match = RegExp(r'Sign in failed:\s*(.+)').firstMatch(errorMessage);
        if (match != null) {
          errorCode = match.group(1)!.trim();
          debugPrint('Extracted error code: $errorCode');
        }
      }

      if (errorCode == 'user-not-found' || errorMessage.contains('user-not-found') || errorMessage.contains('User not found')) {
        errorMessage = 'No account found with this email. Please sign up first.';
      } else if (errorCode == 'wrong-password' || errorCode == 'invalid-credential' ||
          errorMessage.contains('wrong-password') || errorMessage.contains('invalid-credential')) {
        errorMessage = 'Incorrect email or password. Please try again.';
      } else if (errorCode == 'invalid-email' || errorMessage.contains('invalid-email')) {
        errorMessage = 'Invalid email address. Please check your email format.';
      } else if (errorCode == 'user-disabled' || errorMessage.contains('user-disabled')) {
        errorMessage = 'This account has been disabled. Please contact support.';
      } else if (errorCode == 'too-many-requests' || errorMessage.contains('too-many-requests')) {
        errorMessage = 'Too many failed attempts. Please try again later.';
      } else if (errorCode == 'network-request-failed' || errorMessage.contains('network') || errorMessage.contains('unavailable')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      } else if (errorMessage.contains('Please use a valid university email')) {
        errorMessage = 'Please use a valid university email (@cfd.nu.edu.pk)';
      } else {
        errorMessage = errorCode.isNotEmpty
            ? 'Login failed: $errorCode'
            : 'Login failed. Please check your credentials and try again.';
      }

      debugPrint('Showing error message to user: $errorMessage');
      messenger?.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _resetInputFields();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/fast_logo-removebg-preview.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Text('FAST Hostel System'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to home',
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo and Title
                  Center(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/fast_logo-removebg-preview.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'FAST Hostel System',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome Back!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue to your dashboard',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Login Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email Label Above
                        Text(
                          'Email Address',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'student@cfd.nu.edu.pk',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            final lower = value.trim().toLowerCase();
                            if (AdminService.isApprovedAdminEmail(value) || lower.endsWith('@cfd.nu.edu.pk')) {
                              return null;
                            }
                            return 'Use your @cfd.nu.edu.pk email or admin email';
                          },
                        ),
                        // Inline real-time domain hint
                        if (_emailDomainError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 13,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _emailDomainError!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 8, left: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Use your @cfd.nu.edu.pk university email',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Password Label Above
                        Text(
                          'Password',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 8),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/auth/forgot-password'),
                            child: const Text('Forgot Password?'),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login Button
                        Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [
                                      AppTheme.primaryColor.withValues(alpha: 0.5),
                                      AppTheme.primaryDark.withValues(alpha: 0.5),
                                    ]
                                  : AppTheme.primaryGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isLoading
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _login,
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: theme.textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () => context.push('/auth/signup'),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
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