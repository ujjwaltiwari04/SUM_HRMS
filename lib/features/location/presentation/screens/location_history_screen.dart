import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sum_enterprises/features/auth/presentation/providers/auth_provider.dart';
import 'package:sum_enterprises/features/employee/presentation/providers/employee_provider.dart';
import 'package:sum_enterprises/features/location/domain/models/location_model.dart';
import 'package:sum_enterprises/features/location/presentation/providers/location_provider.dart';

class LocationHistoryScreen extends ConsumerStatefulWidget {
  final String? initialEmployeeId;

  const LocationHistoryScreen({
    super.key,
    this.initialEmployeeId,
  });

  @override
  ConsumerState<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends ConsumerState<LocationHistoryScreen> {
  String? _selectedEmployeeId;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.initialEmployeeId;
  }

  Future<void> _openGoogleMaps(double latitude, double longitude) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open external map browser.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(phoneAuthControllerProvider);
    final userRole = authState.user?.role ?? 'employee';
    final currentUserId = authState.user?.uid;

    final isAdmin = userRole == 'admin';

    // If not admin, lock selected employee to current user
    if (!isAdmin) {
      _selectedEmployeeId = currentUserId;
    }

    // Watch employee list for admin filter dropdown
    final employeesAsync = ref.watch(employeeListStreamProvider);

    // Watch the history stream with current filters
    final historyAsync = ref.watch(locationHistoryStreamProvider((
      employeeId: _selectedEmployeeId ?? '',
      date: _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null,
    )));

    return Scaffold(
      key: const ValueKey('location_history_scaffold'),
      appBar: AppBar(
        key: const ValueKey('location_history_app_bar'),
        title: const Text('Route & GPS History'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
              ),
              child: Column(
                children: [
                  if (isAdmin) ...[
                    // Admin selection dropdown
                    employeesAsync.when(
                      data: (employees) {
                        return DropdownButtonFormField<String>(
                          key: const ValueKey('history_employee_dropdown'),
                          value: _selectedEmployeeId,
                          decoration: InputDecoration(
                            labelText: 'Filter by Field Employee',
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: employees.map((emp) {
                            return DropdownMenuItem<String>(
                              value: emp.uid,
                              child: Text(emp.fullName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedEmployeeId = val;
                            });
                          },
                        );
                      },
                      loading: () => const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (err, _) => Text('Error loading employees dropdown: $err'),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Date Picker Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('history_date_picker_btn'),
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 90)),
                              lastDate: DateTime.now(),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _selectedDate = pickedDate;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_month_rounded, size: 18),
                          label: Text(
                            _selectedDate != null
                                ? 'Date: ${DateFormat('dd MMMM yyyy').format(_selectedDate!)}'
                                : 'All Dates (Last 90 days)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (_selectedDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          key: const ValueKey('history_clear_date_btn'),
                          icon: const Icon(Icons.clear_rounded, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedDate = null;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Logs Listing Area
            Expanded(
              child: _selectedEmployeeId == null || _selectedEmployeeId!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isAdmin ? 'Select an employee to view records' : 'Loading location credentials...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : historyAsync.when(
                      data: (logs) {
                        if (logs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 48,
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Tracking Records Found',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'There are no GPS logs recorded for the selected filter queries.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          key: const ValueKey('history_logs_list'),
                          padding: const EdgeInsets.all(16.0),
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            final timeStr = DateFormat('hh:mm:ss a').format(log.timestamp);
                            final dateStr = DateFormat('dd MMM yyyy').format(log.timestamp);
                            final isInternetOnline = log.internetStatus.toLowerCase() == 'online';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant.withOpacity(0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Header: Timestamp, Maps action
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 14,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$timeStr  •  $dateStr',
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton.icon(
                                        key: ValueKey('map_action_btn_$index'),
                                        onPressed: () => _openGoogleMaps(log.latitude, log.longitude),
                                        icon: const Icon(Icons.map_outlined, size: 14),
                                        label: const Text(
                                          'Maps',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // GPS Coordinates row
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.gps_fixed_rounded,
                                        size: 16,
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${log.latitude.toStringAsFixed(6)}, ${log.longitude.toStringAsFixed(6)}',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontFamily: 'JetBrains Mono',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                                  const SizedBox(height: 12),

                                  // Parameter Badges / Row values
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildParamChip(
                                        theme,
                                        'Accuracy: ${log.accuracy.toStringAsFixed(1)} m',
                                        Icons.center_focus_strong_rounded,
                                      ),
                                      _buildParamChip(
                                        theme,
                                        'Speed: ${log.speed != null ? (log.speed! * 3.6).toStringAsFixed(1) : "0.0"} km/h',
                                        Icons.speed_rounded,
                                      ),
                                      _buildParamChip(
                                        theme,
                                        'Battery: ${log.batteryPercentage}%',
                                        Icons.battery_std_rounded,
                                        color: _getBatteryColor(log.batteryPercentage),
                                      ),
                                      _buildParamChip(
                                        theme,
                                        isInternetOnline ? 'Online' : 'Offline',
                                        isInternetOnline ? Icons.signal_wifi_4_bar_rounded : Icons.signal_wifi_off_rounded,
                                        color: isInternetOnline ? Colors.green : Colors.red,
                                      ),
                                      if (log.deviceModel.isNotEmpty)
                                        _buildParamChip(
                                          theme,
                                          log.deviceModel,
                                          Icons.phone_android_rounded,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Failed to load tracking history: $err',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamChip(ThemeData theme, String text, IconData icon, {Color? color}) {
    final activeColor = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: activeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: activeColor.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: activeColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: activeColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int percentage) {
    if (percentage > 50) return Colors.green;
    if (percentage > 20) return Colors.orange;
    return Colors.red;
  }
}
