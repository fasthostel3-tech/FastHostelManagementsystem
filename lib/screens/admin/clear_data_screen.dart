import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClearDataScreen extends StatefulWidget {
  const ClearDataScreen({super.key});

  @override
  State<ClearDataScreen> createState() => _ClearDataScreenState();
}

class _ClearDataScreenState extends State<ClearDataScreen> {
  // What to clear – all ticked by default
  bool _clearApplications = true;
  bool _clearPayments = true;
  bool _clearChallans = true;
  bool _clearGym = true;
  bool _clearMess = true;
  bool _resetRooms = true;
  bool _resetProfiles = true;

  bool _isClearing = false;
  String _statusMessage = '';
  final List<_LogEntry> _log = [];

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── helpers ─────────────────────────────────────────────────────────

  void _addLog(String message, {bool isError = false}) {
    setState(() {
      _log.add(_LogEntry(message, isError: isError));
      _statusMessage = message;
    });
  }

  /// Delete every document in a top-level collection in batches of 400.
  Future<int> _deleteCollection(String collectionPath) async {
    int deleted = 0;
    QuerySnapshot snap;
    do {
      snap = await _db.collection(collectionPath).limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
    } while (snap.docs.length == 400);
    return deleted;
  }

  // ── main wipe logic ──────────────────────────────────────────────────

  Future<void> _performClear() async {
    setState(() {
      _isClearing = true;
      _log.clear();
      _statusMessage = 'Starting…';
    });

    try {
      // 1. Hostel Applications
      if (_clearApplications) {
        _addLog('Deleting hostel applications…');
        final n = await _deleteCollection('hostelApplications');
        _addLog('Done: deleted $n hostel application(s)');
      }

      // 2. Fee Payments (proof records)
      if (_clearPayments) {
        _addLog('Deleting fee payment records…');
        final n1 = await _deleteCollection('feePayments');
        final n2 = await _deleteCollection('payments');
        _addLog('Done: deleted ${n1 + n2} payment record(s)');
      }

      // 3. Fee Challans
      if (_clearChallans) {
        _addLog('Deleting fee challans…');
        final n = await _deleteCollection('feeChallans');
        _addLog('Done: deleted $n challan(s)');
      }

      // 4. Gym Registrations
      if (_clearGym) {
        _addLog('Deleting gym registrations…');
        final gymDocs = await _db.collection('gymRegistrations').get();
        final batch = _db.batch();
        for (final doc in gymDocs.docs) {
          batch.delete(doc.reference);
          // also clear profile subcollection entry
          final studentId = doc.data()['studentId'] as String?;
          if (studentId != null && studentId.isNotEmpty) {
            batch.delete(
              _db.collection('profiles').doc(studentId).collection('gymRegistrations').doc(doc.id),
            );
          }
        }
        await batch.commit();
        _addLog('Done: deleted ${gymDocs.docs.length} gym registration(s)');
      }

      // 5. Mess Registrations
      if (_clearMess) {
        _addLog('Deleting mess registrations…');
        final messDocs = await _db.collection('messRegistrations').get();
        final batch = _db.batch();
        for (final doc in messDocs.docs) {
          batch.delete(doc.reference);
          final studentId = doc.data()['studentId'] as String?;
          if (studentId != null && studentId.isNotEmpty) {
            batch.delete(
              _db.collection('profiles').doc(studentId).collection('messRegistrations').doc(doc.id),
            );
          }
        }
        await batch.commit();
        _addLog('Done: deleted ${messDocs.docs.length} mess registration(s)');
      }

      // 6. Reset room occupancy
      if (_resetRooms) {
        _addLog('Resetting room occupancy…');
        final roomDocs = await _db.collection('rooms').get();
        final batch = _db.batch();
        for (final doc in roomDocs.docs) {
          batch.update(doc.reference, {
            'occupiedBeds': 0,
            'occupants': [],
            'isAvailable': true,
          });
        }
        await batch.commit();
        _addLog('Done: reset ${roomDocs.docs.length} room(s)');
      }

      // 7. Reset profile accommodation fields
      if (_resetProfiles) {
        _addLog('Resetting student profile accommodation data…');
        final profileDocs = await _db
            .collection('profiles')
            .where('role', isEqualTo: 'student')
            .get();
        WriteBatch? batch;
        int count = 0;
        for (final doc in profileDocs.docs) {
          batch ??= _db.batch();
          batch.update(doc.reference, {
            'roomId': FieldValue.delete(),
            'hostelId': FieldValue.delete(),
            'hallId': FieldValue.delete(),
            'applicationId': FieldValue.delete(),
            'roomAssigned': FieldValue.delete(),
          });
          count++;
          // Commit in chunks of 400
          if (count % 400 == 0) {
            await batch.commit();
            batch = null;
          }
        }
        if (batch != null) await batch.commit();
        _addLog('Done: reset $count profile(s)');
      }

      _addLog('All selected data cleared successfully.');
    } catch (e) {
      _addLog('Error: $e', isError: true);
    } finally {
      setState(() => _isClearing = false);
    }
  }

  // ── confirmation dialog ──────────────────────────────────────────────

  Future<void> _showConfirmDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Confirm Wipe', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete the selected registration data. '
              'Students will need to re-apply for accommodation from scratch.\n\n'
              'Type CONFIRM to proceed:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type CONFIRM',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (controller.text.trim() == 'CONFIRM') {
                Navigator.of(ctx).pop(true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please type CONFIRM exactly')),
                );
              }
            },
            child: const Text('Wipe Data', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _performClear();
  }

  // ── build ────────────────────────────────────────────────────────────

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: value ? color.withValues(alpha: 0.06) : null,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        activeThumbColor: color,
        onChanged: _isClearing ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anySelected = _clearApplications ||
        _clearPayments ||
        _clearChallans ||
        _clearGym ||
        _clearMess ||
        _resetRooms ||
        _resetProfiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clear Registration Data'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Warning banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This action is irreversible. Select what to clear and confirm.',
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Data to Clear',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  _buildToggle(
                    title: 'Hostel Applications',
                    subtitle: 'Deletes all hostelApplications documents',
                    icon: Icons.assignment,
                    color: Colors.orange,
                    value: _clearApplications,
                    onChanged: (v) => setState(() => _clearApplications = v),
                  ),
                  _buildToggle(
                    title: 'Payments & Fee Records',
                    subtitle: 'Deletes feePayments and payments collections',
                    icon: Icons.payment,
                    color: Colors.purple,
                    value: _clearPayments,
                    onChanged: (v) => setState(() => _clearPayments = v),
                  ),
                  _buildToggle(
                    title: 'Fee Challans',
                    subtitle: 'Deletes generated challan records',
                    icon: Icons.receipt_long,
                    color: Colors.indigo,
                    value: _clearChallans,
                    onChanged: (v) => setState(() => _clearChallans = v),
                  ),
                  _buildToggle(
                    title: 'Gym Registrations',
                    subtitle: 'Deletes all gym registration records',
                    icon: Icons.fitness_center,
                    color: Colors.red,
                    value: _clearGym,
                    onChanged: (v) => setState(() => _clearGym = v),
                  ),
                  _buildToggle(
                    title: 'Mess Registrations',
                    subtitle: 'Deletes all mess registration records',
                    icon: Icons.restaurant_menu,
                    color: Colors.green,
                    value: _clearMess,
                    onChanged: (v) => setState(() => _clearMess = v),
                  ),
                  _buildToggle(
                    title: 'Reset Room Occupancy',
                    subtitle: 'Sets occupiedBeds = 0 and marks rooms available',
                    icon: Icons.bed,
                    color: Colors.teal,
                    value: _resetRooms,
                    onChanged: (v) => setState(() => _resetRooms = v),
                  ),
                  _buildToggle(
                    title: 'Reset Student Profiles',
                    subtitle: 'Removes roomId, hostelId, applicationId from profiles',
                    icon: Icons.person_off,
                    color: Colors.blueGrey,
                    value: _resetProfiles,
                    onChanged: (v) => setState(() => _resetProfiles = v),
                  ),

                  const SizedBox(height: 24),

                  // Log output
                  if (_log.isNotEmpty) ...[
                    Text('Progress Log',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _log
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    e.message,
                                    style: TextStyle(
                                      color: e.isError
                                          ? Colors.red.shade300
                                          : Colors.greenAccent,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Bottom action bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        anySelected && !_isClearing ? Colors.red.shade700 : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (!anySelected || _isClearing) ? null : _showConfirmDialog,
                  icon: _isClearing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_sweep),
                  label: Text(
                    _isClearing ? _statusMessage : 'Wipe Selected Data',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
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

class _LogEntry {
  final String message;
  final bool isError;
  const _LogEntry(this.message, {this.isError = false});
}
