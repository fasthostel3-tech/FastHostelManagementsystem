import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';

class BankSettingsScreen extends ConsumerStatefulWidget {
  const BankSettingsScreen({super.key});

  @override
  ConsumerState<BankSettingsScreen> createState() => _BankSettingsScreenState();
}

class _BankSettingsScreenState extends ConsumerState<BankSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Global Bank Settings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Accommodation'),
              Tab(text: 'Mess'),
              Tab(text: 'Gym'),
            ],
            indicatorColor: Colors.white,
          ),
        ),
        body: const TabBarView(
          children: [
            _BankSettingsForm(docId: 'bankDetailsAccommodation', title: 'Accommodation Bank Details', description: 'Used for hostel fee and security deposits.'),
            _BankSettingsForm(docId: 'bankDetailsMess', title: 'Mess Bank Details', description: 'Used for automated monthly mess bills.'),
            _BankSettingsForm(docId: 'bankDetailsGym', title: 'Gym Bank Details', description: 'Used for gym registration fees.'),
          ],
        ),
      ),
    );
  }
}

class _BankSettingsForm extends StatefulWidget {
  final String docId;
  final String title;
  final String description;

  const _BankSettingsForm({
    required this.docId,
    required this.title,
    required this.description,
  });

  @override
  State<_BankSettingsForm> createState() => _BankSettingsFormState();
}

class _BankSettingsFormState extends State<_BankSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountTitleController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc(widget.docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _bankNameController.text = data['bankName'] ?? '';
        _accountNumberController.text = data['accountNumber'] ?? '';
        _accountTitleController.text = data['accountTitle'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc(widget.docId)
          .set({
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'accountTitle': _accountTitleController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} saved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance,
                            color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: InputDecoration(
                        labelText: 'Bank Name',
                        hintText: 'e.g., Habib Bank Limited',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.business),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _accountNumberController,
                      decoration: InputDecoration(
                        labelText: 'Account Number (IBAN)',
                        hintText: 'e.g., PK36HABB00000123456789',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _accountTitleController,
                      decoration: InputDecoration(
                        labelText: 'Account Title',
                        hintText: 'e.g., FAST NUCES Collection',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Save Details',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
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
    );
  }
}
