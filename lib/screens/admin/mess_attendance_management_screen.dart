import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/mess_attendance_service.dart';
import '../../config/theme.dart';

class MessAttendanceManagementScreen extends ConsumerStatefulWidget {
  const MessAttendanceManagementScreen({super.key});

  @override
  ConsumerState<MessAttendanceManagementScreen> createState() =>
      _MessAttendanceManagementScreenState();
}

class _MessAttendanceManagementScreenState
    extends ConsumerState<MessAttendanceManagementScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Attendance Management'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Selection
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Select Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
            ),

            const SizedBox(height: 24),

            // Attendance Summary
            FutureBuilder<Map<String, dynamic>>(
              future: ref
                  .read(messAttendanceServiceProvider)
                  .getAttendanceSummary(date: _selectedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final summary = snapshot.data ?? {};
                final attendanceRate = summary['attendanceRate'] as double? ?? 0.0;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Summary',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                context,
                                'Present',
                                '${summary['presentCount'] ?? 0}',
                                AppTheme.successColor,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                context,
                                'Absent',
                                '${summary['absentCount'] ?? 0}',
                                AppTheme.errorColor,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                context,
                                'Rate',
                                '${attendanceRate.toStringAsFixed(1)}%',
                                AppTheme.infoColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // All Attendance Records
            Text(
              'All Attendance Records',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<List<Map<String, dynamic>>>(
              stream: ref
                  .read(messAttendanceServiceProvider)
                  .getAllAttendance(startDate: _selectedDate, endDate: _selectedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final attendance = snapshot.data ?? [];

                if (attendance.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No attendance records for this date'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: attendance.length,
                  itemBuilder: (context, index) {
                    final record = attendance[index];
                    final studentName = record['studentName'] as String? ?? '';
                    final mealType = record['mealType'] as String? ?? '';
                    final isPresent = record['isPresent'] as bool? ?? false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          isPresent ? Icons.check_circle : Icons.cancel,
                          color: isPresent
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                        title: Text(studentName),
                        subtitle: Text(mealType.toUpperCase()),
                        trailing: Text(
                          isPresent ? 'Present' : 'Absent',
                          style: TextStyle(
                            color: isPresent
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
}


