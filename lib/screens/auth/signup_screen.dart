import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';
import '../../config/app_keys.dart';
import 'loading_auth_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fathersNameController = TextEditingController();
  final _arnRollController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  static const String _adminEmail = 'fasthostel3@gmail.com';

  Gender _selectedGender = Gender.male;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _fathersNameController.dispose();
    _arnRollController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidInstitutionEmail(String email) {
    final lower = email.toLowerCase();
    if (lower == _adminEmail) return true;
    return lower.endsWith('@cfd.nu.edu.pk');
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final messenger = AppKeys.scaffoldMessengerKey.currentState;

    if (!_agreeToTerms) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('You must agree to the Hostel Rules and Regulations.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (!_isValidInstitutionEmail(email)) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Only @cfd.nu.edu.pk emails (or admin email) are allowed to sign up.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoadingAuthScreen(message: 'Creating account...'),
          fullscreenDialog: true,
        ),
      );
    }

    try {
      debugPrint('Attempting sign up for $email');
      final authNotifier = ref.read(currentUserProvider.notifier);
      await authNotifier.signUp(
        email: email,
        password: _passwordController.text,
        name: _nameController.text.trim(),
        fathersName: _fathersNameController.text.trim(),
        arnRollNumber: _arnRollController.text.trim().toUpperCase(),
        phone: _phoneController.text.trim(),
        gender: _selectedGender,
        agreeToTerms: _agreeToTerms,
      );

      if (mounted) {
        context.go('/auth/awaiting-verification');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Sign up failed: $e\n$st');
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        String errorMessage = e.toString().replaceFirst('Exception: ', '');
        if (errorMessage.contains('email-already-in-use')) {
          errorMessage = 'An account with this email already exists. Please sign in instead.';
        } else if (errorMessage.contains('weak-password')) {
          errorMessage = 'Password is too weak. Please use a stronger password.';
        } else if (errorMessage.contains('invalid-email')) {
          errorMessage = 'Invalid email address. Please check your email format.';
        } else if (errorMessage.contains('network')) {
          errorMessage = 'Network error. Please check your internet connection and try again.';
        }
        messenger?.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
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
            const Text('Join FAST Hostel'),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/fast_logo-removebg-preview.png',
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'FAST Hostel System',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join FAST Hostel',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create your account to get started',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      'Personal Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Full Name
                    Text(
                      'Full Name',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your full name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Father's Name
                    Text(
                      "Father's Name",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fathersNameController,
                      decoration: const InputDecoration(
                        hintText: "Enter your father's name",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return "Please enter your father's name";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Roll Number
                    Text(
                      'Roll Number',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _arnRollController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., 24A-1234',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your roll number';
                        final pattern = RegExp(r'^\d{2}[A-Za-z]-\d{4}$');
                        if (!pattern.hasMatch(value.toUpperCase())) return 'Invalid format. Use XXN-XXXX (e.g., 24A-1234)';
                        return null;
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 12),
                      child: Text(
                        'Format: XXN-XXXX (e.g., 24A-1234)',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    Text(
                      'Phone Number',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Enter your phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your phone number';
                        final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');
                        if (!RegExp(r'^[0-9]{10,15}$').hasMatch(cleaned)) return 'Please enter a valid phone number (10-15 digits)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    Text(
                      'Gender',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Gender>(
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.wc_outlined),
                      ),
                      items: Gender.values.map((gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Text(gender.toString().split('.').last.toUpperCase()),
                        );
                      }).toList(),
                      validator: (value) {
                        if (value == null) return 'Please select your gender';
                        return null;
                      },
                      onChanged: (value) => setState(() => _selectedGender = value!),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Account Information',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email Address
                    Text(
                      'University Email',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'student@cfd.nu.edu.pk',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter your email';
                        if (!_isValidInstitutionEmail(value.trim())) return 'Use your @cfd.nu.edu.pk email (or admin email) to sign up';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    Text(
                      'Password',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Enter a strong password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a password';
                        if (value.length < 8) return 'Password must be at least 8 characters';
                        if (!value.contains(RegExp(r'[A-Z]'))) return 'Password must contain at least one uppercase letter';
                        if (!value.contains(RegExp(r'[a-z]'))) return 'Password must contain at least one lowercase letter';
                        if (!value.contains(RegExp(r'[0-9]'))) return 'Password must contain at least one number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    Text(
                      'Confirm Password',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        hintText: 'Confirm your password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please confirm your password';
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Terms checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) => setState(() => _agreeToTerms = value!),
                          activeColor: AppTheme.primaryColor,
                        ),
                        const Expanded(
                          child: Text('I agree with the Hostel Rules and Regulations'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // SignUp Button
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
                          onTap: _isLoading ? null : _signUp,
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
                                    'Create Account',
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

                    const SizedBox(height: 16),

                    // Sign In Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ', style: theme.textTheme.bodyMedium),
                        GestureDetector(
                          onTap: () => context.push('/auth/login'),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}