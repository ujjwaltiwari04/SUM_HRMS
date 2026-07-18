import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sum_enterprises/features/employee/presentation/providers/employee_provider.dart';
import 'package:sum_enterprises/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';
import 'package:sum_enterprises/features/attendance/domain/models/leave_request_model.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  late String _selectedDateStr;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _selectedDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  void _adjustDate(int days) {
    final currentDate = DateTime.tryParse(_selectedDateStr) ?? DateTime.now();
    final newDate = currentDate.add(Duration(days: days));
    setState(() {
      _selectedDateStr = DateFormat('yyyy-MM-dd').format(newDate);
    });
  }

  Future<void> _selectDate() async {
    final initialDate = DateTime.tryParse(_selectedDateStr) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDateStr = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Watch data streams
    final employeesAsync = ref.watch(employeeListStreamProvider);
    final pendingLeavesAsync = ref.watch(pendingLeavesStreamProvider);
    final dailyRows = ref.watch(adminDailyAttendanceProvider(_selectedDateStr));

    // Listen to leave approval actions
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

    // Listen to attendance override actions
    ref.listen<AdminAttendanceOverrideState>(adminAttendanceOverrideControllerProvider, (prev, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        ref.read(adminAttendanceOverrideControllerProvider.notifier).clearMessages();
      } else if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(adminAttendanceOverrideControllerProvider.notifier).clearMessages();
      }
    });

    // Compute Summary Card counts
    final presentCount = dailyRows.where((r) => r.attendance.status == 'Present').length;
    final absentCount = dailyRows.where((r) => r.attendance.status == 'Absent').length;
    final leaveCount = dailyRows.where((r) => r.attendance.status == 'Leave').length;
    final halfDayCount = dailyRows.where((r) => r.attendance.status == 'Half Day').length;

    // Filter rows in-memory for Search & Filter Tabs
    final filteredRows = dailyRows.where((row) {
      final query = _searchQuery.toLowerCase().trim();
      if (query.isNotEmpty) {
        final matchesName = row.employee.fullName.toLowerCase().contains(query);
        final matchesId = row.employee.employeeId.toLowerCase().contains(query);
        if (!matchesName && !matchesId) return false;
      }
      if (_selectedFilter != 'All') {
        if (row.attendance.status != _selectedFilter) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance & Leave Management'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Re-read or invalidate state if needed. Handled automatically by Firestore streams.
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Date Header
                  _buildDateHeader(theme),
                  const SizedBox(height: 16),

                  // 2. Attendance Summary Cards
                  _buildSummarySection(theme, presentCount, absentCount, leaveCount, halfDayCount),
                  const SizedBox(height: 20),

                  // 3. Pending Leave Requests Section
                  pendingLeavesAsync.when(
                    data: (leaves) {
                      if (leaves.isEmpty) return const SizedBox.shrink();
                      return _buildPendingLeavesWidget(theme, leaves, employeesAsync.value ?? []);
                    },
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // 4. Employees Attendance Title, Search, and Filters
                  _buildEmployeeListHeader(theme),
                  const SizedBox(height: 12),

                  // 5. Employee Attendance List Rows
                  if (filteredRows.isEmpty)
                    _buildEmptyState(theme)
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredRows.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final row = filteredRows[index];
                        return _buildEmployeeAttendanceRow(context, theme, row);
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader(ThemeData theme) {
    final parsed = DateTime.tryParse(_selectedDateStr) ?? DateTime.now();
    final formatted = DateFormat('EEEE, d MMM yyyy').format(parsed);

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _adjustDate(-1),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      formatted,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: () => _adjustDate(1),
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(ThemeData theme, int present, int absent, int leave, int halfDay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAILY SUMMARY',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _buildSummaryCard(theme, 'Present', present.toString(), Colors.green),
            _buildSummaryCard(theme, 'Absent', absent.toString(), theme.colorScheme.error),
            _buildSummaryCard(theme, 'Leave', leave.toString(), Colors.purple),
            _buildSummaryCard(theme, 'Half Day', halfDay.toString(), Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(ThemeData theme, String title, String count, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  count,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingLeavesWidget(ThemeData theme, List<LeaveRequestModel> leaves, List<UserModel> employees) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PENDING LEAVE REQUESTS (${leaves.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.orange[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leaves.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final leave = leaves[index];
            final emp = employees.firstWhere((e) => e.uid == leave.employeeUid, orElse: () => UserModel(uid: leave.employeeUid, email: '', fullName: 'Unknown', role: UserRole.employee));
            return Card(
              elevation: 0,
              color: Colors.orange[50]?.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          emp.fullName,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          emp.employeeId,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Type: ${leave.type == LeaveType.fullDay ? "Full Day" : "Half Day (${leave.halfDayPeriod == HalfDayPeriod.morning ? 'Morning' : 'Afternoon'})"}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Dates: ${DateFormat('dd MMM').format(leave.startDate)} - ${DateFormat('dd MMM yyyy').format(leave.endDate)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Reason: ${leave.reason}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _handleLeaveAction(context, leave.leaveId, approve: false),
                          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Reject', style: TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _handleLeaveAction(context, leave.leaveId, approve: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Approve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _handleLeaveAction(BuildContext context, String leaveId, {required bool approve}) {
    final commentController = TextEditingController();
    final actionName = approve ? 'Approve' : 'Reject';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$actionName Leave Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Write an optional comment for the employee:'),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter comment...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final comment = commentController.text.trim();
                if (approve) {
                  ref.read(leaveActionControllerProvider.notifier).approveLeave(
                        leaveId: leaveId,
                        adminComment: comment.isEmpty ? null : comment,
                      );
                } else {
                  ref.read(leaveActionControllerProvider.notifier).rejectLeave(
                        leaveId: leaveId,
                        adminComment: comment.isEmpty ? null : comment,
                      );
                }
                Navigator.pop(context);
              },
              child: Text(actionName, style: TextStyle(fontWeight: FontWeight.bold, color: approve ? Colors.green : Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmployeeListHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'EMPLOYEES LIST',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        // Search bar
        TextField(
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search by employee name or ID...',
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        // Horizontal filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Present', 'Absent', 'Leave', 'Half Day'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: ChoiceChip(
                  label: Text(filter, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeAttendanceRow(BuildContext context, ThemeData theme, EmployeeAttendanceRow row) {
    final att = row.attendance;
    final inStr = att.checkInTime != null ? DateFormat('hh:mm a').format(att.checkInTime!) : '--:--';
    final outStr = att.checkOutTime != null ? DateFormat('hh:mm a').format(att.checkOutTime!) : '--:--';

    Color badgeColor = Colors.grey;
    if (att.status == 'Present') badgeColor = Colors.green;
    if (att.status == 'Absent') badgeColor = theme.colorScheme.error;
    if (att.status == 'Leave') badgeColor = Colors.purple;
    if (att.status == 'Half Day') badgeColor = Colors.blue;

    final isOverridden = att.source == 'admin';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: row.employee.profileImageUrl != null
                      ? NetworkImage(row.employee.profileImageUrl!)
                      : null,
                  child: row.employee.profileImageUrl == null
                      ? Text(row.employee.fullName.substring(0, 1).toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.employee.fullName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        row.employee.employeeId,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        att.status.toUpperCase(),
                        style: TextStyle(
                          color: badgeColor == Colors.grey ? Colors.blueGrey : badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isOverridden) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.edit_calendar_rounded, size: 10, color: theme.colorScheme.primary),
                          const SizedBox(width: 2),
                          Text(
                            'OVERRIDDEN',
                            style: TextStyle(fontSize: 8, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.login_rounded, size: 14, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text('In: $inStr', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Icon(Icons.logout_rounded, size: 14, color: Colors.orange[600]),
                    const SizedBox(width: 4),
                    Text('Out: $outStr', style: theme.textTheme.bodySmall),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        context.push('/admin/employee-details', extra: row.employee);
                      },
                      tooltip: 'View Employee Details',
                      icon: Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.primary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => _showOverrideDialog(context, row),
                      tooltip: 'Attendance Override',
                      icon: Icon(Icons.edit_rounded, size: 18, color: theme.colorScheme.primary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOverrideDialog(BuildContext context, EmployeeAttendanceRow row) {
    String selectedStatus = row.attendance.status;
    final reasonController = TextEditingController();
    
    // Initial checkin/checkout times
    DateTime? checkIn = row.attendance.checkInTime ?? DateTime.now();
    DateTime? checkOut = row.attendance.checkOutTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Override: ${row.employee.fullName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'New Status'),
                      items: ['Present', 'Absent', 'Leave', 'Half Day'].map((st) {
                        return DropdownMenuItem(value: st, child: Text(st));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedStatus = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedStatus == 'Present' || selectedStatus == 'Half Day') ...[
                      // Check-in Time Selector
                      ListTile(
                        title: const Text('Check-in Time', style: TextStyle(fontSize: 14)),
                        subtitle: Text(checkIn != null ? DateFormat('hh:mm a').format(checkIn!) : '--:--'),
                        trailing: const Icon(Icons.access_time_rounded),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(checkIn ?? DateTime.now()),
                          );
                          if (time != null) {
                            final now = DateTime.tryParse(_selectedDateStr) ?? DateTime.now();
                            setDialogState(() {
                              checkIn = DateTime(now.year, now.month, now.day, time.hour, time.minute);
                            });
                          }
                        },
                      ),
                      // Check-out Time Selector
                      ListTile(
                        title: const Text('Check-out Time', style: TextStyle(fontSize: 14)),
                        subtitle: Text(checkOut != null ? DateFormat('hh:mm a').format(checkOut!) : 'Not checked out'),
                        trailing: const Icon(Icons.access_time_rounded),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(checkOut ?? DateTime.now()),
                          );
                          if (time != null) {
                            final now = DateTime.tryParse(_selectedDateStr) ?? DateTime.now();
                            setDialogState(() {
                              checkOut = DateTime(now.year, now.month, now.day, time.hour, time.minute);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason for manual override',
                        hintText: 'Enter reason (required)...',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reason is required for audit.')),
                      );
                      return;
                    }

                    final success = await ref
                        .read(adminAttendanceOverrideControllerProvider.notifier)
                        .overrideAttendance(
                          employeeId: row.employee.uid,
                          employeeName: row.employee.fullName,
                          date: _selectedDateStr,
                          status: selectedStatus,
                          reason: reason,
                          checkInTime: (selectedStatus == 'Present' || selectedStatus == 'Half Day') ? checkIn : null,
                          checkOutTime: (selectedStatus == 'Present' || selectedStatus == 'Half Day') ? checkOut : null,
                        );

                    if (success && mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.edit_calendar_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No Employees Found',
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
