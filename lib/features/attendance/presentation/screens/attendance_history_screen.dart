import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';
import 'package:sum_enterprises/features/attendance/presentation/providers/attendance_provider.dart';

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(employeeAttendanceHistoryProvider);

    return Scaffold(
      key: const ValueKey('attendance_history_scaffold'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'ATTENDANCE LOGS',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your complete field location check-in logs',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // History list
              Expanded(
                child: historyAsync.when(
                  data: (history) {
                    if (history.isEmpty) {
                      return _buildEmptyState(theme);
                    }
                    return ListView.separated(
                      key: const ValueKey('history_list_view'),
                      itemCount: history.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final record = history[index];
                        return _buildHistoryCard(context, theme, record);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      'Failed to load history: $error',
                      style: TextStyle(color: theme.colorScheme.error),
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

  Widget _buildHistoryCard(BuildContext context, ThemeData theme, AttendanceModel record) {
    final parsedDate = DateTime.tryParse(record.date) ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(parsedDate);
    
    final checkInStr = record.checkInTime != null 
        ? DateFormat('hh:mm a').format(record.checkInTime!) 
        : '--:--';
        
    final checkOutStr = record.checkOutTime != null 
        ? DateFormat('hh:mm a').format(record.checkOutTime!) 
        : '--:--';

    final isCheckedIn = record.status == 'Checked In';
    final statusColor = isCheckedIn ? Colors.green : Colors.blueGrey;

    // Accuracy helper
    final double? inAccuracy = record.checkInAccuracy;
    final double? outAccuracy = record.checkOutAccuracy;
    final hasLocation = record.checkInLatitude != null && record.checkInLongitude != null;

    return Card(
      key: ValueKey('history_card_${record.attendanceId}'),
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
            // Top row: Date & status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    formattedDate,
                    key: ValueKey('history_date_${record.attendanceId}'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  key: ValueKey('history_badge_${record.attendanceId}'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    record.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 8),

            // Timestamps
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHECK IN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.login_rounded, size: 14, color: Colors.green[600]),
                          const SizedBox(width: 4),
                          Text(
                            checkInStr,
                            key: ValueKey('history_check_in_time_${record.attendanceId}'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHECK OUT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.logout_rounded, size: 14, color: Colors.orange[600]),
                          const SizedBox(width: 4),
                          Text(
                            checkOutStr,
                            key: ValueKey('history_check_out_time_${record.attendanceId}'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Working hours & Location badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      record.workingHours != null 
                          ? 'Shift: ${record.workingHours}' 
                          : (isCheckedIn ? 'Status: Active Shift' : 'Shift: Completed'),
                      key: ValueKey('history_working_hours_${record.attendanceId}'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (hasLocation)
                  Container(
                    key: ValueKey('location_badge_${record.attendanceId}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed_rounded, size: 10, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'GPS Cap ${inAccuracy != null ? '±${inAccuracy.toStringAsFixed(0)}m' : ''}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      key: const ValueKey('history_empty_state'),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No History Yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Your checked-in details and location coordinates will build a timeline here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
