import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/core/widgets/custom_button.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/location/domain/models/location_model.dart';
import 'package:sum_enterprises/features/location/presentation/providers/location_provider.dart';

/// Professional Employee Details Screen inside Admin control panel.
/// Displays detailed employee parameters and triggers mock routing paths.
class EmployeeDetailsScreen extends ConsumerStatefulWidget {
  final UserModel employee;

  const EmployeeDetailsScreen({
    super.key,
    required this.employee,
  });

  @override
  ConsumerState<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends ConsumerState<EmployeeDetailsScreen> {
  bool _isRefreshing = false;

  Future<void> _openGoogleMaps(double latitude, double longitude) async {
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    final Uri googleMapsAppUrl = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');

    try {
      if (await canLaunchUrl(googleMapsAppUrl)) {
        await launchUrl(googleMapsAppUrl);
      } else if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (_) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _refreshDatabaseMetrics() async {
    setState(() {
      _isRefreshing = true;
    });
    // Invalidate the stream to force pulling fresh data from Firestore
    ref.invalidate(employeeLastLocationStreamProvider(widget.employee.uid));
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database metrics refreshed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employee = widget.employee;
    
    final joiningDateStr = employee.joiningDate != null
        ? DateFormat('dd MMMM yyyy').format(employee.joiningDate!)
        : 'Pending Validation';

    return Scaffold(
      key: ValueKey('employee_details_scaffold_${employee.uid}'),
      appBar: AppBar(
        key: ValueKey('employee_details_app_bar_${employee.uid}'),
        title: const Text('Employee Credentials'),
        centerTitle: true,
        leading: IconButton(
          key: ValueKey('employee_details_back_${employee.uid}'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: ValueKey('employee_details_scroll_${employee.uid}'),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card containing photo & state status
              Card(
                key: ValueKey('employee_details_header_card_${employee.uid}'),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Avatar representation with initials
                      CircleAvatar(
                        key: ValueKey('employee_details_avatar_${employee.uid}'),
                        radius: 44,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                        child: Text(
                          employee.fullName.substring(0, 1).toUpperCase(),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Basic parameters
                      Text(
                        employee.fullName,
                        key: ValueKey('employee_details_name_title_${employee.uid}'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        employee.designation,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),

                      // Real-time status indicator
                      Container(
                        key: ValueKey('employee_details_status_indicator_${employee.uid}'),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 4,
                              backgroundColor: Colors.green,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'ACTIVE & AUTHORIZED',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Current Location Section
              Text(
                'CURRENT LIVE LOCATION',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildLiveLocationCard(context, theme, employee.uid),
              const SizedBox(height: 28),

              // Credential breakdown
              Text(
                'PROFILE CREDENTIALS',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),

              _buildDetailTile(theme, 'Employee ID', employee.employeeId, Icons.badge_rounded),
              _buildDetailTile(theme, 'Phone Number', employee.phoneNumber ?? 'N/A', Icons.phone_android_rounded),
              _buildDetailTile(theme, 'Joining Date', joiningDateStr, Icons.calendar_today_rounded),
              _buildDetailTile(theme, 'Email Address', employee.email.isNotEmpty == true ? employee.email : 'N/A', Icons.alternate_email_rounded),
              
              const SizedBox(height: 32),

              // Action buttons group
              Text(
                'ADMINISTRATIVE MANAGEMENT',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Grid / list of management functions navigating to placeholders
              _buildManagementButton(
                context,
                id: 'attendance',
                label: 'Attendance Records',
                icon: Icons.history_rounded,
                route: '/coming-soon/Employee Attendance',
              ),
              _buildManagementButton(
                context,
                id: 'location_history',
                label: 'Location Route History',
                icon: Icons.route_rounded,
                route: '/admin/route-history?employeeId=${employee.uid}',
              ),
              _buildManagementButton(
                context,
                id: 'documents',
                label: 'Shared Documents',
                icon: Icons.folder_open_rounded,
                route: '/coming-soon/Shared Documents',
              ),
              _buildManagementButton(
                context,
                id: 'salary',
                label: 'Salary & Slips',
                icon: Icons.payments_rounded,
                route: '/coming-soon/Salary Logs',
              ),
              _buildManagementButton(
                context,
                id: 'leave',
                label: 'Leave History',
                icon: Icons.time_to_leave_rounded,
                route: '/coming-soon/Leave Records',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Credential line generator
  Widget _buildDetailTile(ThemeData theme, String label, String value, IconData icon) {
    return Card(
      key: ValueKey('detail_tile_${label.replaceAll(' ', '_').toLowerCase()}'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 20),
        title: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        subtitle: Text(
          value,
          key: ValueKey('detail_val_${label.replaceAll(' ', '_').toLowerCase()}'),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Administrative trigger row
  Widget _buildManagementButton(
    BuildContext context, {
    required String id,
    required String label,
    required IconData icon,
    required String route,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: OutlinedButton.icon(
        key: ValueKey('admin_manage_btn_$id'),
        onPressed: () {
          context.push(route);
        },
        icon: Icon(icon, size: 20),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildLiveLocationCard(BuildContext context, ThemeData theme, String employeeId) {
    final locationAsync = ref.watch(employeeLastLocationStreamProvider(employeeId));

    return Card(
      key: const ValueKey('admin_employee_location_card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: locationAsync.when(
          data: (location) {
            if (location == null) {
              return Column(
                children: [
                  Icon(
                    Icons.location_off_rounded,
                    size: 36,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No Active Tracking Data',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This employee is currently off duty, checked out, or has not synced location data yet today.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('refresh_empty_location_btn'),
                    onPressed: _isRefreshing ? null : _refreshDatabaseMetrics,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh'),
                  ),
                ],
              );
            }

            final latLongStr = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
            final lastUpdatedStr = DateFormat('hh:mm:ss a').format(location.timestamp);
            final speedStr = location.speed != null 
                ? '${(location.speed! * 3.6).toStringAsFixed(1)} km/h'
                : '0.0 km/h';

            final now = DateTime.now();
            final difference = now.difference(location.timestamp);
            final bool isLive = difference.inMinutes < 15;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header: Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 5,
                          backgroundColor: isLive ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isLive ? 'LIVE TRACKING ACTIVE' : 'OFFLINE / DELAYED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isLive ? Colors.green : Colors.grey[700],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      location.deviceModel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lat/Long Coordinate Badge
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.gps_fixed_rounded, color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Captured Coordinates',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              latLongStr,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'JetBrains Mono',
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info Grid
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                  ),
                  children: [
                    _buildTrackingSubField(theme, 'Last Sync', lastUpdatedStr, Icons.update_rounded),
                    _buildTrackingSubField(theme, 'Accuracy', '${location.accuracy.toStringAsFixed(1)} m', Icons.center_focus_weak_rounded),
                    _buildTrackingSubField(theme, 'Speed', speedStr, Icons.speed_rounded),
                    _buildTrackingSubField(theme, 'Battery', '${location.batteryPercentage}%', Icons.battery_charging_full_rounded),
                    _buildTrackingSubField(theme, 'Device Network', location.internetStatus, Icons.wifi_rounded),
                  ],
                ),
                const SizedBox(height: 20),

                // Button Actions Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        key: const ValueKey('view_on_maps_btn'),
                        onPressed: () => _openGoogleMaps(location.latitude, location.longitude),
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text('View on Google Maps'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        key: const ValueKey('refresh_gps_data_btn'),
                        onPressed: _isRefreshing ? null : _refreshDatabaseMetrics,
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Error loading coordinates: $err',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingSubField(ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
