import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sum_enterprises/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:sum_enterprises/features/attendance/domain/models/leave_request_model.dart';
import 'package:sum_enterprises/features/auth/presentation/providers/auth_provider.dart';

class EmployeeLeaveScreen extends ConsumerStatefulWidget {
  const EmployeeLeaveScreen({super.key});

  @override
  ConsumerState<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends ConsumerState<EmployeeLeaveScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(phoneAuthControllerProvider).user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in first.')),
      );
    }

    final leavesAsync = ref.watch(employeeLeavesStreamProvider(user.uid));

    // Listen to leave action success/error
    ref.listen<LeaveActionState>(leaveActionControllerProvider, (prev, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        ref.read(leaveActionControllerProvider.notifier).clearMessages();
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(leaveActionControllerProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leave Requests'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyLeaveBottomSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply Leave'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'YOUR LEAVE HISTORY',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: leavesAsync.when(
                  data: (leaves) {
                    if (leaves.isEmpty) {
                      return _buildEmptyState(theme);
                    }
                    return ListView.separated(
                      itemCount: leaves.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final leave = leaves[index];
                        return _buildLeaveRequestCard(context, theme, leave);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      'Failed to load leaves: $error',
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

  Widget _buildLeaveRequestCard(BuildContext context, ThemeData theme, LeaveRequestModel leave) {
    final startStr = DateFormat('dd MMM yyyy').format(leave.startDate);
    final endStr = DateFormat('dd MMM yyyy').format(leave.endDate);
    final dateRangeStr = leave.startDate.day == leave.endDate.day &&
            leave.startDate.month == leave.endDate.month &&
            leave.startDate.year == leave.endDate.year
        ? startStr
        : '$startStr - $endStr';

    final isPending = leave.status == LeaveStatus.pending;
    final isApproved = leave.status == LeaveStatus.approved;
    final isCancelled = leave.status == LeaveStatus.cancelled;

    Color statusColor = Colors.orange;
    if (isApproved) {
      statusColor = Colors.green;
    } else if (leave.status == LeaveStatus.rejected) {
      statusColor = theme.colorScheme.error;
    } else if (isCancelled) {
      statusColor = Colors.grey;
    }

    final actionController = ref.watch(leaveActionControllerProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  leave.type == LeaveType.fullDay ? 'Full Day Leave' : 'Half Day Leave',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    leave.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (leave.type == LeaveType.halfDay && leave.halfDayPeriod != null) ...[
              const SizedBox(height: 4),
              Text(
                'Period: ${leave.halfDayPeriod == HalfDayPeriod.morning ? "Morning" : "Afternoon"}',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  dateRangeStr,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Reason: ${leave.reason}',
              style: theme.textTheme.bodyMedium,
            ),
            if (leave.adminComment != null && leave.adminComment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Admin Comment: ${leave.adminComment}',
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: actionController.isLoading
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Cancel Leave'),
                              content: const Text('Are you sure you want to cancel this pending leave request?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('No'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                                  child: const Text('Yes, Cancel'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            ref.read(leaveActionControllerProvider.notifier).cancelLeave(leave.leaveId);
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 14),
                  label: const Text('Cancel Request', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.beach_access_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Leaves Applied Yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to apply for a leave.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showApplyLeaveBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return const _ApplyLeaveFormSheet();
      },
    );
  }
}

class _ApplyLeaveFormSheet extends ConsumerStatefulWidget {
  const _ApplyLeaveFormSheet();

  @override
  ConsumerState<_ApplyLeaveFormSheet> createState() => _ApplyLeaveFormSheetState();
}

class _ApplyLeaveFormSheetState extends ConsumerState<_ApplyLeaveFormSheet> {
  final _reasonController = TextEditingController();
  LeaveType _selectedType = LeaveType.fullDay;
  HalfDayPeriod _selectedPeriod = HalfDayPeriod.morning;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionState = ref.watch(leaveActionControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 20.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Apply for Leave',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Leave Type Selector
          DropdownButtonFormField<LeaveType>(
            value: _selectedType,
            decoration: InputDecoration(
              labelText: 'Leave Type',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: const [
              DropdownMenuItem(value: LeaveType.fullDay, child: Text('Full Day Leave')),
              DropdownMenuItem(value: LeaveType.halfDay, child: Text('Half Day Leave')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedType = val;
                  if (val == LeaveType.halfDay) {
                    _endDate = _startDate; // Half day is always single day
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // Half Day Period Selector
          if (_selectedType == LeaveType.halfDay) ...[
            DropdownButtonFormField<HalfDayPeriod>(
              value: _selectedPeriod,
              decoration: InputDecoration(
                labelText: 'Half Day Period',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: const [
                DropdownMenuItem(value: HalfDayPeriod.morning, child: Text('Morning (First Half)')),
                DropdownMenuItem(value: HalfDayPeriod.afternoon, child: Text('Afternoon (Second Half)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPeriod = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          // Dates Picker
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectStartDate,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text('Start: ${DateFormat('dd MMM').format(_startDate)}'),
                ),
              ),
              if (_selectedType == LeaveType.fullDay) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectEndDate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text('End: ${DateFormat('dd MMM').format(_endDate)}'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Reason Field
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason for leave',
              hintText: 'Describe why you are taking leave...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),

          // Submit button
          ElevatedButton(
            onPressed: actionState.isLoading
                ? null
                : () async {
                    final success = await ref
                        .read(leaveActionControllerProvider.notifier)
                        .applyLeave(
                          type: _selectedType,
                          halfDayPeriod: _selectedType == LeaveType.halfDay ? _selectedPeriod : null,
                          startDate: _startDate,
                          endDate: _selectedType == LeaveType.halfDay ? _startDate : _endDate,
                          reason: _reasonController.text,
                        );
                    if (success && mounted) {
                      Navigator.pop(context);
                    }
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: actionState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit Application'),
          ),
        ],
      ),
    );
  }
}
