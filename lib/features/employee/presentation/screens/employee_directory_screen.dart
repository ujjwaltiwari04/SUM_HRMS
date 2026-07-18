import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/employee/presentation/providers/employee_provider.dart';

/// Screen listing all SUM Enterprises employees in real-time.
/// Includes support for search filters and redirects to individual credentials details.
class EmployeeDirectoryScreen extends ConsumerStatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  ConsumerState<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends ConsumerState<EmployeeDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  bool _matchesQuery(UserModel employee) {
    if (_searchQuery.isEmpty) return true;

    final nameMatches = employee.fullName.toLowerCase().contains(_searchQuery);
    final idMatches = employee.employeeId.toLowerCase().contains(_searchQuery);
    final designationMatches = employee.designation.toLowerCase().contains(_searchQuery);
    final departmentMatches = employee.department?.toLowerCase().contains(_searchQuery) ?? false;
    final phoneMatches = employee.phoneNumber?.toLowerCase().contains(_searchQuery) ?? false;

    return nameMatches || idMatches || designationMatches || departmentMatches || phoneMatches;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employeesAsync = ref.watch(employeeListStreamProvider);

    return Scaffold(
      key: const ValueKey('employee_directory_scaffold'),
      appBar: AppBar(
        key: const ValueKey('employee_directory_app_bar'),
        title: const Text('Employee Directory'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Input Control
              SearchBar(
                key: const ValueKey('directory_search_bar'),
                controller: _searchController,
                hintText: 'Search by name, ID, department...',
                leading: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                trailing: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      key: const ValueKey('directory_search_clear_btn'),
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
                ],
                elevation: WidgetStateProperty.all(0.0),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                backgroundColor: WidgetStateProperty.all(theme.colorScheme.surface),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Employee Directory Headline
              Text(
                'ALL REGISTERED EMPLOYEES',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),

              // Directory Listing
              Expanded(
                child: employeesAsync.when(
                  data: (employees) {
                    final filteredEmployees = employees.where(_matchesQuery).toList();

                    if (filteredEmployees.isEmpty) {
                      return _buildEmptyState(theme);
                    }

                    return ListView.separated(
                      key: const ValueKey('directory_list_view'),
                      itemCount: filteredEmployees.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final employee = filteredEmployees[index];
                        return _buildEmployeeCard(context, theme, employee);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Failed to load corporate directory: $error',
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        textAlign: TextAlign.center,
                      ),
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

  Widget _buildEmployeeCard(BuildContext context, ThemeData theme, UserModel employee) {
    final hasImage = employee.profileImageUrl != null && employee.profileImageUrl!.isNotEmpty;
    final statusColor = employee.isActive ? Colors.green : Colors.grey;

    return Card(
      key: ValueKey('directory_employee_card_${employee.uid}'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: InkWell(
        key: ValueKey('directory_employee_ink_${employee.uid}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          context.push('/admin/employee-details', extra: employee);
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                backgroundImage: hasImage ? NetworkImage(employee.profileImageUrl!) : null,
                child: !hasImage
                    ? Text(
                        employee.fullName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Details Group
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            employee.fullName,
                            key: ValueKey('directory_name_${employee.uid}'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            employee.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Employee ID & Designation
                    Text(
                      'ID: ${employee.employeeId} • ${employee.designation}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Department Name
                    if (employee.department != null && employee.department!.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.corporate_fare_rounded,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            employee.department!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Navigation indicator arrow
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      key: const ValueKey('directory_empty_container'),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No Employees Found',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'No employee profiles matches the search query details.'
                : 'No employee directory records found.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
