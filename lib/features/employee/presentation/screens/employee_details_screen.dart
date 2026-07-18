import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/core/widgets/custom_button.dart';
import 'package:sum_enterprises/core/widgets/custom_confirmation_dialog.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/location/domain/models/location_model.dart';
import 'package:sum_enterprises/features/location/presentation/providers/location_provider.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';
import 'package:sum_enterprises/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:sum_enterprises/features/employee/presentation/providers/employee_provider.dart';

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
  bool _isEditMode = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _designationController;
  late TextEditingController _employeeIdController;
  String? _selectedDepartment;

  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _designationFocusNode = FocusNode();
  final _employeeIdFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _designationController = TextEditingController();
    _employeeIdController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _employeeIdController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _designationFocusNode.dispose();
    _employeeIdFocusNode.dispose();
    super.dispose();
  }

  void _enterEditMode(UserModel employee) {
    _nameController.text = employee.fullName;
    _phoneController.text = employee.phoneNumber ?? '';
    _designationController.text = employee.designation;
    _employeeIdController.text = employee.employeeId;
    _selectedDepartment = employee.department;
    setState(() {
      _isEditMode = true;
    });
  }

  void _handleCancel(UserModel employee) async {
    if (_hasUnsavedChanges(employee)) {
      final discard = await _showDiscardDialog();
      if (discard) {
        setState(() {
          _isEditMode = false;
        });
      }
    } else {
      setState(() {
        _isEditMode = false;
      });
    }
  }

  bool _hasUnsavedChanges(UserModel employee) {
    return _nameController.text != employee.fullName ||
        _phoneController.text != (employee.phoneNumber ?? '') ||
        _designationController.text != employee.designation ||
        _employeeIdController.text != employee.employeeId ||
        _selectedDepartment != employee.department;
  }

  Future<bool> _showDiscardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard changes?'),
          actions: [
            TextButton(
              key: const ValueKey('btn_cancel_discard'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('btn_confirm_discard'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _submitForm(UserModel employee) async {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();

      // Check if employee ID is unique across other users
      final newId = _employeeIdController.text.trim().toUpperCase();
      final existingEmployees = ref.read(employeeListStreamProvider).value ?? [];
      if (existingEmployees.any((e) => e.uid != employee.uid && e.employeeId.toUpperCase() == newId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee ID already exists for another employee.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Save changes?'),
            content: const Text('Are you sure you want to save changes to this employee profile?'),
            actions: [
              TextButton(
                key: const ValueKey('btn_cancel_save'),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                key: const ValueKey('btn_confirm_save'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (confirm == true && mounted) {
        final updated = employee.copyWith(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          designation: _designationController.text.trim(),
          employeeId: _employeeIdController.text.trim(),
          department: _selectedDepartment,
        );

        ref.read(employeeActionControllerProvider.notifier).updateEmployee(employee: updated);
      }
    }
  }

  void _showToggleStatusDialog(BuildContext context, UserModel employee) {
    final theme = Theme.of(context);

    if (employee.isActive) {
      // Deactivate confirmation
      showDialog(
        context: context,
        builder: (context) => CustomConfirmationDialog(
          key: const ValueKey('deactivate_confirmation_dialog'),
          title: 'Deactivate Employee?',
          message: 'The employee will no longer be able to:',
          bulletPoints: const [
            'Log into the application',
            'Check In / Check Out',
            'Apply Leave',
            'Access the Employee Portal',
          ],
          cancelText: 'Cancel',
          confirmText: 'Deactivate',
          confirmButtonColor: theme.colorScheme.error,
          confirmTextColor: theme.colorScheme.onError,
          icon: Icons.warning_amber_rounded,
          iconColor: theme.colorScheme.error,
          onConfirm: () {
            ref.read(employeeActionControllerProvider.notifier).deactivateEmployee(employee.uid);
          },
        ),
      );
    } else {
      // Activate confirmation
      showDialog(
        context: context,
        builder: (context) => CustomConfirmationDialog(
          key: const ValueKey('activate_confirmation_dialog'),
          title: 'Activate Employee?',
          message: 'The employee will regain access to the application immediately.',
          cancelText: 'Cancel',
          confirmText: 'Activate',
          confirmButtonColor: theme.colorScheme.primary,
          confirmTextColor: theme.colorScheme.onPrimary,
          icon: Icons.check_circle_outline_rounded,
          iconColor: theme.colorScheme.primary,
          onConfirm: () {
            ref.read(employeeActionControllerProvider.notifier).activateEmployee(employee.uid);
          },
        ),
      );
    }
  }

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
    final employeesAsync = ref.watch(employeeListStreamProvider);
    final employee = employeesAsync.when(
      data: (list) => list.firstWhere((e) => e.uid == widget.employee.uid, orElse: () => widget.employee),
      loading: () => widget.employee,
      error: (_, __) => widget.employee,
    );
    
    final joiningDateStr = employee.joiningDate != null
        ? DateFormat('dd MMMM yyyy').format(employee.joiningDate!)
        : 'Pending Validation';

    final todayAttendanceAsync = ref.watch(employeeTodayAttendanceStreamProvider(widget.employee.uid));
    final overrideState = ref.watch(adminAttendanceOverrideControllerProvider);
    final actionState = ref.watch(employeeActionControllerProvider);

    ref.listen<EmployeeActionState>(employeeActionControllerProvider, (previous, next) {
      if (next.isSuccess && next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('edit_employee_success_snackbar'),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(next.successMessage!)),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(employeeActionControllerProvider.notifier).clearMessages();
        setState(() {
          _isEditMode = false;
        });
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('edit_employee_error_snackbar'),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(employeeActionControllerProvider.notifier).clearMessages();
      }
    });

    ref.listen<AdminAttendanceOverrideState>(adminAttendanceOverrideControllerProvider, (previous, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(adminAttendanceOverrideControllerProvider.notifier).clearMessages();
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(adminAttendanceOverrideControllerProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      key: ValueKey('employee_details_scaffold_${employee.uid}'),
      appBar: AppBar(
        key: ValueKey('employee_details_app_bar_${employee.uid}'),
        title: Text(_isEditMode ? 'Edit Profile' : 'Employee Credentials'),
        centerTitle: true,
        leading: IconButton(
          key: ValueKey(_isEditMode 
              ? 'employee_details_cancel_${employee.uid}' 
              : 'employee_details_back_${employee.uid}'),
          icon: Icon(_isEditMode ? Icons.close_rounded : Icons.arrow_back_rounded),
          onPressed: () {
            if (_isEditMode) {
              _handleCancel(employee);
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (!_isEditMode) ...[
            IconButton(
              key: const ValueKey('btn_edit_employee'),
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Profile',
              onPressed: () => _enterEditMode(employee),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('btn_employee_more_actions'),
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'toggle_status') {
                  _showToggleStatusDialog(context, employee);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  key: const ValueKey('menu_toggle_status'),
                  value: 'toggle_status',
                  child: Text(employee.isActive ? 'Deactivate Employee' : 'Activate Employee'),
                ),
              ],
            ),
          ] else
            IconButton(
              key: const ValueKey('btn_save_employee'),
              icon: const Icon(Icons.check_rounded),
              tooltip: 'Save Changes',
              onPressed: () => _submitForm(employee),
            ),
        ],
      ),
      body: PopScope(
        canPop: !_isEditMode,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_isEditMode) {
            if (_hasUnsavedChanges(employee)) {
              final discard = await _showDiscardDialog();
              if (discard && mounted) {
                setState(() {
                  _isEditMode = false;
                });
                context.pop();
              }
            } else {
              setState(() {
                _isEditMode = false;
              });
              context.pop();
            }
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
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
                        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // Avatar representation with initials
                            CircleAvatar(
                              key: ValueKey('employee_details_avatar_${employee.uid}'),
                              radius: 44,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                              child: Text(
                                (_isEditMode && _nameController.text.isNotEmpty 
                                        ? _nameController.text 
                                        : employee.fullName)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Basic parameters
                            Text(
                              _isEditMode && _nameController.text.isNotEmpty 
                                  ? _nameController.text 
                                  : employee.fullName,
                              key: ValueKey('employee_details_name_title_${employee.uid}'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isEditMode && _designationController.text.isNotEmpty 
                                  ? _designationController.text 
                                  : employee.designation,
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
                                color: Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
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

                    // Current Location Section (Hidden in Edit Mode)
                    if (!_isEditMode) ...[
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
                    ],

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

                    if (!_isEditMode) ...[
                      _buildDetailTile(theme, 'Employee ID', employee.employeeId, Icons.badge_rounded),
                      _buildDetailTile(theme, 'Full Name', employee.fullName, Icons.person_outline_rounded),
                      _buildDetailTile(theme, 'Designation', employee.designation, Icons.work_outline_rounded),
                      _buildDetailTile(theme, 'Phone Number', employee.phoneNumber ?? 'N/A', Icons.phone_android_rounded),
                      _buildDetailTile(theme, 'Department', employee.department ?? 'N/A', Icons.corporate_fare_rounded),
                      _buildDetailTile(theme, 'Joining Date', joiningDateStr, Icons.calendar_today_rounded),
                      _buildDetailTile(theme, 'Email Address', employee.email.isNotEmpty == true ? employee.email : 'N/A', Icons.alternate_email_rounded),
                    ] else ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Employee ID (Editable Field)
                            TextFormField(
                              key: const ValueKey('edit_field_employee_id'),
                              controller: _employeeIdController,
                              focusNode: _employeeIdFocusNode,
                              textInputAction: TextInputAction.next,
                              onChanged: (val) => setState(() {}),
                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_nameFocusNode),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter the Employee ID.';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Employee ID',
                                prefixIcon: const Icon(Icons.badge_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Full Name
                            TextFormField(
                              key: const ValueKey('edit_field_full_name'),
                              controller: _nameController,
                              focusNode: _nameFocusNode,
                              textInputAction: TextInputAction.next,
                              onChanged: (val) => setState(() {}),
                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_designationFocusNode),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter the full name.';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Designation
                            TextFormField(
                              key: const ValueKey('edit_field_designation'),
                              controller: _designationController,
                              focusNode: _designationFocusNode,
                              textInputAction: TextInputAction.next,
                              onChanged: (val) => setState(() {}),
                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocusNode),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter the designation.';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Designation',
                                prefixIcon: const Icon(Icons.work_outline_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Phone Number
                            TextFormField(
                              key: const ValueKey('edit_field_phone'),
                              controller: _phoneController,
                              focusNode: _phoneFocusNode,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onChanged: (val) => setState(() {}),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter the phone number.';
                                }
                                final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
                                if (!phoneRegex.hasMatch(val.trim())) {
                                  return 'Please enter a valid phone number (e.g. +91XXXXXXXXXX).';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: const Icon(Icons.phone_android_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Department Dropdown
                            DropdownButtonFormField<String>(
                              key: const ValueKey('edit_field_department'),
                              value: _selectedDepartment,
                              decoration: InputDecoration(
                                labelText: 'Department',
                                prefixIcon: const Icon(Icons.corporate_fare_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Operations', child: Text('Operations')),
                                DropdownMenuItem(value: 'Technical & IT', child: Text('Technical & IT')),
                                DropdownMenuItem(value: 'Human Resources', child: Text('Human Resources')),
                                DropdownMenuItem(value: 'Sales & Marketing', child: Text('Sales & Marketing')),
                                DropdownMenuItem(value: 'Finance', child: Text('Finance')),
                                DropdownMenuItem(value: 'Administration', child: Text('Administration')),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedDepartment = val;
                                });
                              },
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please select a department.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Joining Date (Read Only Visual)
                            _buildDetailTile(theme, 'Joining Date (Read Only)', joiningDateStr, Icons.calendar_today_rounded),
                            const SizedBox(height: 8),

                            // Email Address (Read Only Visual)
                            _buildDetailTile(theme, 'Email Address (Read Only)', employee.email.isNotEmpty == true ? employee.email : 'N/A', Icons.alternate_email_rounded),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],

                    // Attendance statistics (Read-only section)
                    const SizedBox(height: 28),
                    Text(
                      'ATTENDANCE STATISTICS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAttendanceStatsCard(theme, ref.watch(adminAttendanceListProvider((date: null, employeeId: employee.uid)))),

                    // System metadata (Read-only section)
                    const SizedBox(height: 28),
                    Text(
                      'SYSTEM & AUDIT INFORMATION',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailTile(theme, 'Firebase UID', employee.uid, Icons.key_rounded),
                    _buildDetailTile(theme, 'Role', employee.role.name.toUpperCase(), Icons.admin_panel_settings_rounded),
                    _buildDetailTile(theme, 'Created At', employee.createdAt != null ? DateFormat('dd MMMM yyyy, hh:mm a').format(employee.createdAt!) : 'N/A', Icons.history_rounded),
                    _buildDetailTile(theme, 'Created By', employee.createdBy ?? 'N/A', Icons.person_search_rounded),
                    if (employee.lastUpdatedAt != null)
                      _buildDetailTile(theme, 'Last Updated At', DateFormat('dd MMMM yyyy, hh:mm a').format(employee.lastUpdatedAt!), Icons.update_rounded),
                    if (employee.lastUpdatedBy != null)
                      _buildDetailTile(theme, 'Last Updated By', employee.lastUpdatedBy!, Icons.edit_note_rounded),

                    const SizedBox(height: 28),

                    // Attendance Override Section (Hidden in Edit Mode)
                    if (!_isEditMode) ...[
                      Text(
                        'ATTENDANCE OVERRIDE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAttendanceOverrideCard(context, theme, todayAttendanceAsync, overrideState),
                      const SizedBox(height: 32),
                    ],

                    // Action buttons group (Hidden in Edit Mode)
                    if (!_isEditMode) ...[
                      Text(
                        'ADMINISTRATIVE MANAGEMENT',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildManagementButton(
                        context,
                        id: 'attendance',
                        label: 'Attendance Records',
                        icon: Icons.history_rounded,
                        route: '/admin/attendance',
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
                  ],
                ),
              ),
              if (actionState.isLoading)
                Container(
                  key: const ValueKey('loading_overlay'),
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
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
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
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

  /// Attendance Stats Card
  Widget _buildAttendanceStatsCard(ThemeData theme, AsyncValue<List<AttendanceModel>> historyAsync) {
    return Card(
      key: const ValueKey('attendance_stats_card'),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: historyAsync.when(
          data: (history) {
            final totalShifts = history.length;
            final completedShifts = history.where((r) => r.status == 'Present' && r.checkOutTime != null).length;
            final activeShifts = history.where((r) => r.status == 'Present' && r.checkInTime != null && r.checkOutTime == null).length;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatMetric(theme, 'Total Shifts', '$totalShifts'),
                _buildStatMetric(theme, 'Completed', '$completedShifts'),
                _buildStatMetric(theme, 'On Field', '$activeShifts'),
              ],
            );
          },
          loading: () => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, _) => Text(
            'Failed to load statistics: $err',
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildStatMetric(ThemeData theme, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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

  Future<void> _showOverrideDialog({
    required BuildContext context,
    required bool isCheckIn,
    required AttendanceModel? currentRecord,
  }) async {
    final theme = Theme.of(context);
    final reasonController = TextEditingController();
    final timeController = TextEditingController(
      text: DateFormat('hh:mm a').format(DateTime.now()),
    );
    DateTime selectedTime = DateTime.now();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Manual Override ${isCheckIn ? "Check In" : "Check Out"}'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Provide override reason and time for auditing.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Time Selector
                    TextFormField(
                      controller: timeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Select Time',
                        prefixIcon: const Icon(Icons.access_time_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedTime),
                        );
                        if (picked != null) {
                          final now = DateTime.now();
                          final newTime = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            picked.hour,
                            picked.minute,
                          );
                          setState(() {
                            selectedTime = newTime;
                            timeController.text = picked.format(context);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Audit Reason Field
                    TextFormField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: 'Override Reason',
                        hintText: 'Enter reason (e.g. Forgot phone)',
                        prefixIcon: const Icon(Icons.comment_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter an override reason.';
                        }
                        if (val.trim().length < 5) {
                          return 'Reason must be at least 5 characters.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context);
                      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

                      if (isCheckIn) {
                        await ref.read(adminAttendanceOverrideControllerProvider.notifier).overrideCheckIn(
                              employeeId: widget.employee.uid,
                              employeeName: widget.employee.fullName,
                              date: todayDate,
                              checkInTime: selectedTime,
                              reason: reasonController.text.trim(),
                            );
                      } else {
                        await ref.read(adminAttendanceOverrideControllerProvider.notifier).overrideCheckOut(
                              employeeId: widget.employee.uid,
                              date: todayDate,
                              checkOutTime: selectedTime,
                              reason: reasonController.text.trim(),
                            );
                      }
                    }
                  },
                  child: const Text('SUBMIT'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceOverrideCard(
    BuildContext context,
    ThemeData theme,
    AsyncValue<AttendanceModel?> todayAttendanceAsync,
    AdminAttendanceOverrideState overrideState,
  ) {
    return Card(
      key: const ValueKey('attendance_override_card'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow ?? theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: todayAttendanceAsync.when(
          data: (record) {
            final today = DateTime.now();
            final todayOnly = DateTime(today.year, today.month, today.day);
            final joiningOnly = widget.employee.joiningDate != null 
                ? DateTime(widget.employee.joiningDate!.year, widget.employee.joiningDate!.month, widget.employee.joiningDate!.day)
                : null;

            final hasCheckIn = record != null && record.checkInTime != null;
            final hasCheckOut = record != null && record.checkOutTime != null;
            final isCheckedIn = record != null && record.status == 'Present' && record.checkOutTime == null;

            String statusText = 'Absent / Not Checked In';
            Color statusColor = theme.colorScheme.error;

            if (joiningOnly != null && todayOnly.isBefore(joiningOnly)) {
              statusText = 'Not Joined Yet';
              statusColor = Colors.grey;
            } else if (record != null) {
              if (record.status == 'Present') {
                if (isCheckedIn) {
                  statusText = 'Checked In';
                  statusColor = Colors.green;
                } else if (hasCheckOut) {
                  statusText = 'Checked Out';
                  statusColor = theme.colorScheme.primary;
                }
              } else {
                statusText = record.status;
                statusColor = record.status == 'Leave' ? Colors.purple : Colors.blue;
              }
            }

            final timeFormat = DateFormat('hh:mm a');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Status:',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        statusText.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (hasCheckIn) ...[
                  Row(
                    children: [
                      Icon(Icons.login_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Check-In Time: ',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        timeFormat.format(record.checkInTime!),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (record.source == 'admin') ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Overridden by Admin: ${record.overrideReason ?? ""}',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'MANUAL',
                              style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (hasCheckOut) ...[
                  Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Check-Out Time: ',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        timeFormat.format(record.checkOutTime!),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (record.source == 'admin' && record.overrideReason != null) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Overridden by Admin: ${record.overrideReason ?? ""}',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'MANUAL',
                              style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (record.workingHours != null) ...[
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          'Working Hours: ',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          record.workingHours!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('btn_override_check_in'),
                        onPressed: (hasCheckIn || overrideState.isLoading)
                            ? null
                            : () => _showOverrideDialog(
                                  context: context,
                                  isCheckIn: true,
                                  currentRecord: record,
                                ),
                        icon: const Icon(Icons.login_rounded, size: 16),
                        label: const Text('Override Check In', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('btn_override_check_out'),
                        onPressed: (!isCheckedIn || overrideState.isLoading)
                            ? null
                            : () => _showOverrideDialog(
                                  context: context,
                                  isCheckIn: false,
                                  currentRecord: record,
                                ),
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('Override Check Out', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Failed to load daily attendance: $err',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
