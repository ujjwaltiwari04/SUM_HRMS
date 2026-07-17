import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sum_enterprises/features/employee/presentation/providers/employee_provider.dart';
import 'package:sum_enterprises/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  String? _selectedEmployeeId;
  String? _selectedDateStr; // Format: YYYY-MM-DD

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Watch employee list stream to populate dropdown filter
    final employeesAsync = ref.watch(employeeListStreamProvider);

    // Watch the filtered attendance logs
    final attendanceLogsAsync = ref.watch(adminAttendanceListProvider((
      date: _selectedDateStr,
      employeeId: _selectedEmployeeId,
    )));

    // Date picker handler
    Future<void> _selectDate() async {
      final initialDate = _selectedDateStr != null 
          ? DateTime.tryParse(_selectedDateStr!) ?? DateTime.now()
          : DateTime.now();

      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2025),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );

      if (picked != null) {
        setState(() {
          _selectedDateStr = DateFormat('yyyy-MM-dd').format(picked);
        });
      }
    }

    return Scaffold(
      key: const ValueKey('admin_attendance_scaffold'),
      appBar: AppBar(
        key: const ValueKey('admin_attendance_appbar'),
        title: const Text('Employee Attendance Logs'),
        centerTitle: true,
        actions: [
          if (_selectedDateStr != null || _selectedEmployeeId != null)
            IconButton(
              key: const ValueKey('admin_clear_filters_btn'),
              icon: const Icon(Icons.filter_alt_off_rounded),
              tooltip: 'Clear filters',
              onPressed: () {
                setState(() {
                  _selectedDateStr = null;
                  _selectedEmployeeId = null;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filters Section Title
              Text(
                'FILTER OPERATIONAL LOGS',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),

              // Filter Controls (Employee Selector dropdown + Date selection)
              Row(
                children: [
                  // Employee filter dropdown
                  Expanded(
                    flex: 3,
                    child: employeesAsync.when(
                      data: (employees) {
                        return DropdownButtonFormField<String>(
                          key: const ValueKey('admin_employee_filter_dropdown'),
                          value: _selectedEmployeeId,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            labelText: 'Employee',
                            labelStyle: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Employees', style: TextStyle(fontSize: 13)),
                            ),
                            ...employees.map((emp) {
                              return DropdownMenuItem<String>(
                                value: emp.uid,
                                child: Text(emp.fullName, style: const TextStyle(fontSize: 13)),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedEmployeeId = val;
                            });
                          },
                        );
                      },
                      loading: () => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, __) => const Text('Error loading employees'),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Date filter button
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      key: const ValueKey('admin_date_filter_btn'),
                      onPressed: _selectDate,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text(
                        _selectedDateStr != null 
                            ? DateFormat('dd MMM').format(DateTime.parse(_selectedDateStr!)) 
                            : 'Select Date',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              const SizedBox(height: 16),

              // Attendance log count header
              attendanceLogsAsync.when(
                data: (logs) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LOGS FOUND (${logs.length})',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_selectedDateStr != null)
                      Text(
                        'Date: $_selectedDateStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // Attendance list results
              Expanded(
                child: attendanceLogsAsync.when(
                  data: (logs) {
                    if (logs.isEmpty) {
                      return _buildEmptyState(theme);
                    }
                    return ListView.separated(
                      key: const ValueKey('admin_attendance_list_view'),
                      itemCount: logs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return _buildAttendanceLogTile(context, theme, log);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      'Failed to load operational logs: $error',
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
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

  Widget _buildAttendanceLogTile(BuildContext context, ThemeData theme, AttendanceModel log) {
    final parsedDate = DateTime.tryParse(log.date) ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy').format(parsedDate);

    final checkInStr = log.checkInTime != null 
        ? DateFormat('hh:mm a').format(log.checkInTime!) 
        : '--:--';
    final checkOutStr = log.checkOutTime != null 
        ? DateFormat('hh:mm a').format(log.checkOutTime!) 
        : '--:--';

    final isCheckedIn = log.status == 'Checked In';
    final statusColor = isCheckedIn ? Colors.green : Colors.blueGrey;
    final hasLocation = log.checkInLatitude != null && log.checkInLongitude != null;

    return Card(
      key: ValueKey('admin_log_tile_${log.attendanceId}'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: InkWell(
        key: ValueKey('admin_log_ink_${log.attendanceId}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          context.push('/admin/attendance-details', extra: log);
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee Name, Status & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.employeeName,
                          key: ValueKey('admin_log_name_${log.attendanceId}'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$formattedDate • ${log.workingHours ?? 'Active Shift'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    key: ValueKey('admin_log_badge_${log.attendanceId}'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      log.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
              const SizedBox(height: 8),

              // Time & GPS available badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.login_rounded, size: 14, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        checkInStr,
                        key: ValueKey('admin_log_in_time_${log.attendanceId}'),
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.logout_rounded, size: 14, color: Colors.orange[600]),
                      const SizedBox(width: 4),
                      Text(
                        checkOutStr,
                        key: ValueKey('admin_log_out_time_${log.attendanceId}'),
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (hasLocation)
                    Row(
                      children: [
                        Icon(Icons.gps_fixed_rounded, size: 10, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'GPS OK',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      key: const ValueKey('admin_attendance_empty_container'),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.edit_calendar_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No Records Found',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'No employee attendance records matches the selected criteria.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
