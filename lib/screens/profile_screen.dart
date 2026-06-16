import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_service.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _rollNumberController;
  Gender? _selectedGender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _rollNumberController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser != null) {
      setState(() {
        _nameController.text = currentUser.name;
        _phoneController.text = currentUser.phone;
        _emailController.text = currentUser.email;
        _rollNumberController.text = currentUser.arnRollNumber;
        _selectedGender = currentUser.gender;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profileService = ref.read(profileServiceProvider);
      final userId = ref.read(currentUserProvider).value?.uid;
      if (userId != null) {
        await profileService.updateProfile(userId, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'arnRollNumber': _rollNumberController.text.trim(),
          'gender': _selectedGender.toString().split('.').last,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isFieldMissing(String? value) {
    return value == null || value.isEmpty;
  }

  Widget _buildFieldIndicator(String label, String? value, {bool isRequired = true}) {
    final isMissing = isRequired && _isFieldMissing(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMissing ? Colors.orange.withValues(alpha:0.1) : Colors.green.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMissing ? Colors.orange : Colors.green,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isMissing ? Icons.warning : Icons.check_circle,
            color: isMissing ? Colors.orange : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${isMissing ? "Missing" : "Complete"}',
              style: TextStyle(
                color: isMissing ? Colors.orange.shade900 : Colors.green.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Completion Status
              const Text(
                'Profile Completion Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, child) {
                  final currentUser = ref.watch(currentUserProvider).value;
                  return Column(
                    children: [
                      _buildFieldIndicator('Gender', currentUser?.gender.toString().split('.').last),
                      _buildFieldIndicator('Email', currentUser?.email),
                      _buildFieldIndicator('Roll Number', currentUser?.arnRollNumber),
                      _buildFieldIndicator('Phone Number', currentUser?.phone),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Profile Edit Form
              const Text(
                'Update Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Gender>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: Gender.values.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedGender = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select your gender';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rollNumberController,
                decoration: const InputDecoration(
                  labelText: 'Roll Number',
                  hintText: 'e.g., 24A-1234',
                  border: OutlineInputBorder(),
                  helperText: 'Format: XXN-XXXX (e.g., 24A-1234)',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your roll number';
                  }
                  final pattern = RegExp(r'^\d{2}[A-Za-z]-\d{4}$');
                  if (!pattern.hasMatch(value.toUpperCase())) {
                    return 'Invalid format. Use XXN-XXXX (e.g., 24A-1234)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _isLoading ? null : _updateProfile,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? Theme.of(context).primaryColor.withOpacity(0.5)
                        : Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Update Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _rollNumberController.dispose();
    super.dispose();
  }
}
