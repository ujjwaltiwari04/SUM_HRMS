import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';

class AttendanceDetailScreen extends StatelessWidget {
  final AttendanceModel attendance;

  const AttendanceDetailScreen({
    super.key,
    required this.attendance,
  });

  /// Launch coordinate pin in native browser or Google Maps app
  Future<void> _openLocationOnMap(BuildContext context, double? lat, double? lng, String label) async {
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS coordinates not captured for this action.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps application';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error launching maps: $e\nCoordinates: $lat, $lng'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsedDate = DateTime.tryParse(attendance.date) ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(parsedDate);

    final checkInStr = attendance.checkInTime != null
        ? DateFormat('hh:mm:ss a').format(attendance.checkInTime!)
        : 'Pending';
    final checkOutStr = attendance.checkOutTime != null
        ? DateFormat('hh:mm:ss a').format(attendance.checkOutTime!)
        : 'Active Shift';

    final isCheckedIn = attendance.status == 'Present' && attendance.checkInTime != null && attendance.checkOutTime == null;
    final isCheckedOut = attendance.status == 'Present' && attendance.checkOutTime != null;

    Color statusColor = Colors.grey;
    if (attendance.status == 'Present') {
      statusColor = isCheckedIn ? Colors.green : Colors.blueGrey;
    } else if (attendance.status == 'Absent') {
      statusColor = theme.colorScheme.error;
    } else if (attendance.status == 'Leave') {
      statusColor = Colors.purple;
    } else if (attendance.status == 'Half Day') {
      statusColor = Colors.blue;
    }

    return Scaffold(
      key: const ValueKey('attendance_detail_scaffold'),
      appBar: AppBar(
        key: const ValueKey('attendance_detail_appbar'),
        title: const Text('Attendance Details'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('attendance_detail_scroll'),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee Info Header Card
              Card(
                key: const ValueKey('detail_header_card'),
                elevation: 0,
                color: theme.colorScheme.primary.withOpacity(0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                        child: Text(
                          attendance.employeeName.isNotEmpty
                              ? attendance.employeeName.substring(0, 1).toUpperCase()
                              : 'E',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        attendance.employeeName,
                        key: const ValueKey('detail_employee_name'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Employee ID: ${attendance.employeeId.substring(0, Math.min(8, attendance.employeeId.length)).toUpperCase()}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        key: const ValueKey('detail_status_badge'),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          attendance.status == 'Present'
                              ? (isCheckedIn ? 'CHECKED IN' : 'CHECKED OUT')
                              : attendance.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Date & Overall statistics
              Text(
                'LOG DETAILS',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),

              _buildMetaRow(theme, 'Shift Date', formattedDate, Icons.calendar_today_rounded),
              _buildMetaRow(
                theme,
                'Shift Duration',
                attendance.workingHours ?? 'Active on Field',
                Icons.timer_rounded,
                isHighlight: true,
              ),
              const SizedBox(height: 24),

              // Check-In Details Card
              _buildLocationDetailsCard(
                context,
                theme,
                title: 'CHECK IN DETAILS',
                time: checkInStr,
                lat: attendance.checkInLatitude,
                lng: attendance.checkInLongitude,
                accuracy: attendance.checkInAccuracy,
                icon: Icons.login_rounded,
                color: Colors.green,
              ),
              const SizedBox(height: 16),

              // Check-Out Details Card
              _buildLocationDetailsCard(
                context,
                theme,
                title: 'CHECK OUT DETAILS',
                time: checkOutStr,
                lat: attendance.checkOutLatitude,
                lng: attendance.checkOutLongitude,
                accuracy: attendance.checkOutAccuracy,
                icon: Icons.logout_rounded,
                color: Colors.orange,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(ThemeData theme, String label, String value, IconData icon, {bool isHighlight = false}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: isHighlight ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, size: 20),
        title: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isHighlight ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDetailsCard(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String time,
    required double? lat,
    required double? lng,
    required double? accuracy,
    required IconData icon,
    required Color color,
  }) {
    final hasLocation = lat != null && lng != null;

    return Card(
      key: ValueKey('detail_loc_card_${title.replaceAll(' ', '_').toLowerCase()}'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
            const SizedBox(height: 12),

            // Time Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Timestamp',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  time,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // GPS Coordinates Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GPS Coordinates',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  hasLocation 
                      ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}' 
                      : 'Unavailable',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'JetBrainsMono',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Accuracy Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Precision Accuracy',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  hasLocation && accuracy != null 
                      ? '±${accuracy.toStringAsFixed(1)} Meters' 
                      : 'Unavailable',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: (hasLocation && accuracy != null && accuracy <= 20) 
                        ? Colors.green 
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Map button
            if (hasLocation)
              ElevatedButton.icon(
                key: ValueKey('detail_map_btn_${title.replaceAll(' ', '_').toLowerCase()}'),
                onPressed: () => _openLocationOnMap(context, lat, lng, title),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text(
                  'VIEW ON GOOGLE MAPS',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'GPS data not available for this session check.',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
