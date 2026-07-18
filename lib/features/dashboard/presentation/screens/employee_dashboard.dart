import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sum_enterprises/core/widgets/custom_button.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/auth/presentation/providers/auth_provider.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';
import 'package:sum_enterprises/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:sum_enterprises/features/attendance/presentation/screens/attendance_history_screen.dart';
import 'package:sum_enterprises/features/location/domain/models/location_model.dart';
import 'package:sum_enterprises/features/location/presentation/providers/location_provider.dart';

/// Comprehensive Employee Dashboard implementing a bottom navigation bar.
/// Tabs:
/// 0: Home (Welcome, Quick Actions Grid, Corporate Notices)
/// 1: Attendance (Placeholder)
/// 2: Documents (Placeholder)
/// 3: Profile (Professional employee credentials read from Firestore)
class EmployeeDashboard extends ConsumerStatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  ConsumerState<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends ConsumerState<EmployeeDashboard> {
  int _currentIndex = 0;
  bool _isRefreshingLocation = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(phoneAuthControllerProvider);
    final user = authState.user;

    // Listen to attendance action results (GPS validation, permissions, connectivity, checks)
    ref.listen<AttendanceActionState>(attendanceActionControllerProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('attendance_error_snackbar'),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(attendanceActionControllerProvider.notifier).clearMessages();
      }

      if (next.successMessage != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('attendance_success_dialog'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Success',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              next.successMessage!,
              style: theme.textTheme.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        ref.read(attendanceActionControllerProvider.notifier).clearMessages();
      }
    });

    final todayAttendanceAsync = ref.watch(todayAttendanceStreamProvider);
    final actionState = ref.watch(attendanceActionControllerProvider);
    final todayAtt = todayAttendanceAsync.value;
    final isNotCheckedIn = todayAtt == null || todayAtt.status == 'Absent';
    final isCheckedIn = todayAtt != null && todayAtt.status == 'Present' && todayAtt.checkInTime != null && todayAtt.checkOutTime == null;
    final isCheckedOut = todayAtt != null && todayAtt.status == 'Present' && todayAtt.checkOutTime != null;
    final isOnLeave = todayAtt != null && (todayAtt.status == 'Leave' || todayAtt.status == 'Half Day');

    final isCheckInDisabled = isCheckedIn || isCheckedOut || isOnLeave || actionState.isLoading;
    final isCheckOutDisabled = isNotCheckedIn || isCheckedOut || isOnLeave || actionState.isLoading;

    // Greeting message computed by device clock
    String greeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }

    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    // Pages configuration
    final List<Widget> tabs = [
      // TAB 0: HOME VIEW
      SingleChildScrollView(
        key: const ValueKey('employee_home_scroll'),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              key: const ValueKey('employee_header_card'),
              elevation: 0,
              color: theme.colorScheme.primary.withOpacity(0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Company Name Text
                        Text(
                          'SUM ENTERPRISES',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            letterSpacing: 2.0,
                          ),
                        ),
                        // Status Badge
                        Container(
                          key: const ValueKey('employee_status_badge'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isCheckedIn 
                                ? Colors.blue 
                                : (isCheckedOut ? Colors.grey : Colors.green)).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (isCheckedIn 
                                  ? Colors.blue 
                                  : (isCheckedOut ? Colors.grey : Colors.green)).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: isCheckedIn 
                                    ? Colors.blue 
                                    : (isCheckedOut ? Colors.grey : Colors.green),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCheckedIn 
                                    ? 'On Duty' 
                                    : (isCheckedOut ? 'Shift Done' : 'Ready to Work'),
                                style: TextStyle(
                                  color: isCheckedIn 
                                      ? Colors.blue 
                                      : (isCheckedOut ? Colors.grey[700] : Colors.green),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${greeting()},',
                      key: const ValueKey('employee_greeting_label'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            user?.fullName ?? 'Sum Employee',
                            key: const ValueKey('employee_display_name'),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Logo on right side, below status badge
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.15),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.5),
                            child: Image.asset(
                              'assets/images/LOGO.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.corporate_fare_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          key: const ValueKey('employee_current_date'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // TODAY'S ATTENDANCE STATUS CARD
            _buildTodayStatusCard(theme, todayAttendanceAsync),
            const SizedBox(height: 20),

            // LIVE GPS TRACKING STATUS CARD
            _buildTrackingStatusCard(context, theme, user?.uid, isCheckedIn),
            const SizedBox(height: 28),

            // Quick Actions Section Title
            Text(
              'QUICK ACTIONS',
              key: const ValueKey('quick_actions_title'),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Quick Actions Bento Grid (Material Design 3 Cards)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.25,
              children: [
                _buildActionCard(
                  context,
                  id: 'check_in',
                  title: actionState.isLoading && !isCheckInDisabled ? 'Checking In...' : 'Check In',
                  icon: Icons.login_rounded,
                  color: Colors.green,
                  isDisabled: isCheckInDisabled,
                  onTap: () {
                    ref.read(attendanceActionControllerProvider.notifier).checkIn();
                  },
                ),
                _buildActionCard(
                  context,
                  id: 'check_out',
                  title: actionState.isLoading && !isCheckOutDisabled ? 'Checking Out...' : 'Check Out',
                  icon: Icons.logout_rounded,
                  color: Colors.orange,
                  isDisabled: isCheckOutDisabled,
                  onTap: () {
                    if (todayAtt != null) {
                      ref.read(attendanceActionControllerProvider.notifier).checkOut(todayAtt);
                    }
                  },
                ),
                _buildActionCard(
                  context,
                  id: 'attendance',
                  title: 'Attendance History',
                  icon: Icons.edit_calendar_rounded,
                  color: Colors.indigo,
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                ),
                _buildActionCard(
                  context,
                  id: 'documents',
                  title: 'Documents',
                  icon: Icons.folder_shared_rounded,
                  color: Colors.teal,
                  route: '/coming-soon/Documents',
                ),
                _buildActionCard(
                  context,
                  id: 'salary_slip',
                  title: 'Salary Slip',
                  icon: Icons.payments_rounded,
                  color: Colors.purple,
                  route: '/coming-soon/Salary Slip',
                ),
                _buildActionCard(
                  context,
                  id: 'apply_leave',
                  title: 'Apply Leave',
                  icon: Icons.pending_actions_rounded,
                  color: Colors.blue,
                  route: '/employee/leave',
                ),
                _buildActionCard(
                  context,
                  id: 'route_history',
                  title: 'My GPS History',
                  icon: Icons.route_rounded,
                  color: Colors.blueAccent,
                  onTap: () {
                    context.push('/admin/route-history?employeeId=${user?.uid}');
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Notices Section Title
            Text(
              'COMPANY NOTICES',
              key: const ValueKey('company_notices_title'),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Notices List Placeholders
            _buildNoticeCard(
              theme,
              id: 'notice_meeting',
              title: 'Meeting tomorrow at 10 AM',
              time: 'Today, 09:30 AM',
              icon: Icons.video_camera_front_rounded,
              color: theme.colorScheme.primary,
              description: 'All staff members are expected to join the technical review of current operations.',
            ),
            _buildNoticeCard(
              theme,
              id: 'notice_salary',
              title: 'Salary credited successfully',
              time: 'Yesterday, 06:15 PM',
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.green,
              description: 'Corporate payroll disbursement for the previous operational cycle is completed.',
            ),
            _buildNoticeCard(
              theme,
              id: 'notice_holiday',
              title: 'Holiday announcement',
              time: '2 days ago',
              icon: Icons.celebration_rounded,
              color: Colors.amber[800]!,
              description: 'In observance of regional festivities, the corporate offices will remain closed next Monday.',
            ),
          ],
        ),
      ),

      // TAB 1: ATTENDANCE HISTORY VIEW
      const AttendanceHistoryScreen(),

      // TAB 2: DOCUMENTS COMING SOON
      const _ComingSoonTabPlaceholder(title: 'Corporate Documents'),

      // TAB 3: PROFILE VIEW
      _buildProfileView(theme, user, authState.isLoading),
    ];

    return Scaffold(
      key: const ValueKey('employee_dashboard_scaffold'),
      appBar: AppBar(
        key: const ValueKey('employee_app_bar'),
        title: Text(_currentIndex == 3 ? 'My Corporate Profile' : 'SUM Employee Portal'),
        centerTitle: true,
        actions: _currentIndex == 3
            ? []
            : [
                IconButton(
                  key: const ValueKey('employee_app_bar_logout_button'),
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Logout session',
                  onPressed: () {
                    ref.read(phoneAuthControllerProvider.notifier).logout();
                  },
                )
              ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: tabs[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('employee_bottom_nav_bar'),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            key: ValueKey('nav_dest_home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            key: ValueKey('nav_dest_attendance'),
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Attendance',
          ),
          NavigationDestination(
            key: ValueKey('nav_dest_documents'),
            icon: Icon(Icons.folder_open_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Docs',
          ),
          NavigationDestination(
            key: ValueKey('nav_dest_profile'),
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Reusable Bento Action Card with feedback mechanics
  Widget _buildActionCard(
    BuildContext context, {
    required String id,
    required String title,
    required IconData icon,
    required Color color,
    String? route,
    VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      key: ValueKey('action_ink_well_$id'),
      onTap: isDisabled ? null : (onTap ?? () {
        if (route != null) {
          context.push(route);
        }
      }),
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isDisabled ? 0.45 : 1.0,
        child: Card(
          key: ValueKey('action_card_$id'),
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        key: ValueKey('action_text_$id'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (isDisabled)
                      Icon(Icons.lock_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Today's Status Card displaying live checked-in / checked-out details
  Widget _buildTodayStatusCard(ThemeData theme, AsyncValue<AttendanceModel?> todayAttendanceAsync) {
    return todayAttendanceAsync.when(
      data: (attendance) {
        final isCheckedIn = attendance != null && attendance.status == 'Present' && attendance.checkInTime != null && attendance.checkOutTime == null;
        final isCheckedOut = attendance != null && attendance.status == 'Present' && attendance.checkOutTime != null;
        
        final checkInTimeStr = attendance?.checkInTime != null 
            ? DateFormat('hh:mm a').format(attendance!.checkInTime!) 
            : 'Pending';
        final checkOutTimeStr = attendance?.checkOutTime != null 
            ? DateFormat('hh:mm a').format(attendance!.checkOutTime!) 
            : 'Pending';
        final workingHrsStr = attendance?.workingHours ?? 'Active Shift';

        final String statusText;
        if (attendance == null) {
          statusText = 'NOT CHECKED IN';
        } else if (attendance.status == 'Present') {
          statusText = isCheckedIn ? 'CHECKED IN' : 'CHECKED OUT';
        } else {
          statusText = attendance.status.toUpperCase();
        }

        Color getBadgeColor() {
          if (attendance == null) return Colors.amber;
          if (attendance.status == 'Present') {
            return isCheckedIn ? Colors.green : Colors.blueGrey;
          }
          if (attendance.status == 'Absent') return theme.colorScheme.error;
          return Colors.purple; // Leave or Half Day
        }
        final badgeColor = getBadgeColor();

        return Card(
          key: const ValueKey('today_status_card_real'),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TODAY'S STATUS",
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Container(
                      key: const ValueKey('today_status_badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: badgeColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: badgeColor == Colors.amber ? Colors.amber[800] : badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeMetric(
                        theme,
                        'Checked In',
                        checkInTimeStr,
                        Icons.login_rounded,
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildTimeMetric(
                        theme,
                        'Checked Out',
                        checkOutTimeStr,
                        Icons.logout_rounded,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_rounded, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Shift Duration:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          workingHrsStr,
                          key: const ValueKey('today_working_hours_txt'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (attendance?.checkInAccuracy != null)
                      Row(
                        children: [
                          Icon(Icons.gps_fixed_rounded, size: 12, color: theme.colorScheme.primary.withOpacity(0.8)),
                          const SizedBox(width: 4),
                          Text(
                            'GPS Cap',
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
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error loading status: $err'),
        ),
      ),
    );
  }

  /// Real-time live tracking card showing current GPS coordinates, status, and manual refresh button
  Widget _buildTrackingStatusCard(BuildContext context, ThemeData theme, String? employeeId, bool isCheckedIn) {
    if (employeeId == null) return const SizedBox.shrink();

    final lastLocationAsync = ref.watch(employeeLastLocationStreamProvider(employeeId));

    return Card(
      key: const ValueKey('tracking_status_card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Section title and live status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "GPS LIVE TRACKING",
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  key: const ValueKey('tracking_status_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isCheckedIn ? Colors.green : Colors.grey).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isCheckedIn ? Colors.green : Colors.grey).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: isCheckedIn ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCheckedIn ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: isCheckedIn ? Colors.green : Colors.grey[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!isCheckedIn) ...[
              // Privacy off-duty representation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off_rounded,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tracking is completely offline.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To protect your privacy, location services only update while you are checked-in and actively on shift.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // When employee is checked-in and active
              lastLocationAsync.when(
                data: (location) {
                  if (location == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Initializing first location sync...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final latLongStr = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
                  final lastUpdatedStr = DateFormat('hh:mm:ss a').format(location.timestamp);
                  final speedStr = location.speed != null 
                      ? '${(location.speed! * 3.6).toStringAsFixed(1)} km/h'
                      : '0.0 km/h';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Location coordinates row
                      Row(
                        children: [
                          Icon(Icons.my_location_rounded, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Location (GPS)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  latLongStr,
                                  key: const ValueKey('tracking_lat_long_txt'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'JetBrains Mono',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                      const SizedBox(height: 12),

                      // Grid of detailed fields: Last Updated, Accuracy, Speed, Battery
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.8,
                        ),
                        children: [
                          _buildTrackingSubField(
                            theme,
                            'Last Sync',
                            lastUpdatedStr,
                            Icons.update_rounded,
                          ),
                          _buildTrackingSubField(
                            theme,
                            'Accuracy',
                            '${location.accuracy.toStringAsFixed(1)} m',
                            Icons.gps_fixed_rounded,
                          ),
                          _buildTrackingSubField(
                            theme,
                            'Speed',
                            speedStr,
                            Icons.speed_rounded,
                          ),
                          _buildTrackingSubField(
                            theme,
                            'Battery',
                            '${location.batteryPercentage}%',
                            Icons.battery_charging_full_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Open in Google Maps button
                      ElevatedButton.icon(
                        key: const ValueKey('tracking_open_maps_btn'),
                        onPressed: () async {
                          final uri = Uri.parse(
                            'geo:${location.latitude},${location.longitude}?q=${location.latitude},${location.longitude}',
                          );
                          final webUri = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
                          );
                          try {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              await launchUrl(webUri, mode: LaunchMode.externalApplication);
                            }
                          } catch (_) {
                            await launchUrl(webUri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text(
                          'VIEW ON GOOGLE MAPS',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                          foregroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Manual refresh button
                      OutlinedButton.icon(
                        key: const ValueKey('tracking_refresh_btn'),
                        onPressed: _isRefreshingLocation ? null : _refreshLocation,
                        icon: _isRefreshingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          _isRefreshingLocation ? 'Refreshing Location...' : 'Refresh Location',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
                    'Failed to read tracking parameters: $err',
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
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

  /// Manual location refresh engine
  Future<void> _refreshLocation() async {
    setState(() {
      _isRefreshingLocation = true;
    });

    try {
      // 1. Verify and request Geolocator Permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on this device.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied by user.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // 2. Fetch high accuracy position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // 3. Assemble full metrics
      final batteryLevel = await Battery().batteryLevel;
      final result = await Connectivity().checkConnectivity();
      final internetStatus = result == ConnectivityResult.none ? 'Offline' : 'Online';
      
      final info = DeviceInfoPlugin();
      String deviceModel = 'Mobile Device';
      if (Platform.isAndroid) {
        final androidInfo = await info.androidInfo;
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await info.iosInfo;
        deviceModel = iosInfo.utsname.machine;
      }

      final currentUser = ref.read(phoneAuthControllerProvider).user;
      if (currentUser != null) {
        final locationModel = LocationModel(
          locationId: '',
          employeeId: currentUser.uid,
          employeeName: currentUser.fullName,
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
          accuracy: position.accuracy,
          speed: position.speed >= 0 ? position.speed : null,
          batteryPercentage: batteryLevel,
          deviceModel: deviceModel,
          internetStatus: internetStatus,
        );

        await ref.read(locationRepositoryProvider).saveLocationUpdate(locationModel);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS Coordinates refreshed and logged.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update GPS: ${e.toString().replaceAll('Exception: ', '')}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingLocation = false;
        });
      }
    }
  }

  /// Small metric helper for status cards
  Widget _buildTimeMetric(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Reusable Announcement card
  Widget _buildNoticeCard(
    ThemeData theme, {
    required String id,
    required String title,
    required String time,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Card(
      key: ValueKey('notice_card_$id'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          key: ValueKey('notice_title_$id'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formatted functional corporate profile view page
  Widget _buildProfileView(ThemeData theme, UserModel? user, bool isLoading) {
    final joiningDateStr = user?.joiningDate != null
        ? DateFormat('dd MMMM yyyy').format(user!.joiningDate!)
        : 'Pending Validation';

    return SingleChildScrollView(
      key: const ValueKey('profile_scroll_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Upper Visual Info Card
          Card(
            key: const ValueKey('profile_main_card'),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Photo / Initials representation
                  CircleAvatar(
                    key: const ValueKey('profile_big_avatar'),
                    radius: 48,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                    child: Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName.substring(0, 1).toUpperCase()
                          : 'S',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display Details
                  Text(
                    user?.fullName ?? 'Sum Employee',
                    key: const ValueKey('profile_name_title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user?.designation ?? 'Corporate Specialist',
                      key: const ValueKey('profile_designation_badge'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Core Data List Section
          Text(
            'EMPLOYEE CREDENTIALS',
            key: const ValueKey('credentials_section_title'),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),

          _buildProfileField(theme, 'Employee ID', user?.employeeId ?? 'SUM-0000', Icons.badge_rounded),
          _buildProfileField(theme, 'Registered Phone', user?.phoneNumber ?? 'N/A', Icons.phone_android_rounded),
          _buildProfileField(theme, 'Designation', user?.designation ?? 'Corporate Specialist', Icons.work_history_rounded),
          _buildProfileField(theme, 'Corporate Email', user?.email.isNotEmpty == true ? user!.email : 'No registered email', Icons.alternate_email_rounded),
          _buildProfileField(theme, 'Joining Date', joiningDateStr, Icons.calendar_month_rounded),
          const SizedBox(height: 36),

          // Logout facilities
          CustomButton(
            key: const ValueKey('profile_logout_button'),
            text: 'LOG OUT SESSION',
            icon: Icons.power_settings_new_rounded,
            backgroundColor: theme.colorScheme.error,
            textColor: theme.colorScheme.onError,
            isLoading: isLoading,
            onPressed: () {
              ref.read(phoneAuthControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }

  /// Single line field generator
  Widget _buildProfileField(ThemeData theme, String label, String value, IconData icon) {
    return Card(
      key: ValueKey('profile_field_${label.replaceAll(' ', '_').toLowerCase()}'),
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
          key: ValueKey('profile_val_${label.replaceAll(' ', '_').toLowerCase()}'),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Helper screen representation inside Tabs for "Coming Soon" page components
class _ComingSoonTabPlaceholder extends StatelessWidget {
  final String title;

  const _ComingSoonTabPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 60,
            color: theme.colorScheme.primary.withOpacity(0.4),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'COMING SOON',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 2.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This tab will load your personal records, historical graphs, and real-time validation layers in the next production update.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
