import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/auth/presentation/providers/auth_provider.dart';
import 'package:sum_enterprises/features/auth/presentation/screens/login_screen.dart';
import 'package:sum_enterprises/features/dashboard/presentation/screens/admin_dashboard.dart';
import 'package:sum_enterprises/features/dashboard/presentation/screens/employee_dashboard.dart';
import 'package:sum_enterprises/features/placeholder/presentation/screens/coming_soon_screen.dart';
import 'package:sum_enterprises/features/employee/presentation/screens/employee_details_screen.dart';
import 'package:sum_enterprises/features/employee/presentation/screens/employee_directory_screen.dart';
import 'package:sum_enterprises/features/employee/presentation/screens/add_employee_screen.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';
import 'package:sum_enterprises/features/attendance/presentation/screens/admin_attendance_screen.dart';
import 'package:sum_enterprises/features/attendance/presentation/screens/attendance_detail_screen.dart';
import 'package:sum_enterprises/features/location/presentation/screens/location_history_screen.dart';
import 'package:sum_enterprises/features/attendance/presentation/screens/employee_leave_screen.dart';

// Keys for navigating without a BuildContext (e.g. from background messaging services)
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Decoupled, state-aware GoRouter Provider.
/// Automatically triggers recalculations and navigates/redirects when the auth state changes.
final appRouterPro = Provider<GoRouter>((ref) {
  // Watch auth state to trigger redirect evaluations when user logs in/out
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    
    // Core state-aware redirection engine
    redirect: (context, state) {
      final String location = state.uri.toString();
      final bool isLoggingIn = location == '/login';
      final bool isSplash = location == '/splash';

      return authState.when(
        data: (user) {
          // If no authenticated user is present
          if (user == null) {
            // Prevent endless redirection loops
            if (isLoggingIn) return null;
            return '/login';
          }

          // If the user IS authenticated and trying to hit Login or Splash, route them to their respective Dashboard
          if (isLoggingIn || isSplash) {
            return user.isAdmin ? '/admin/dashboard' : '/employee/dashboard';
          }

          // Enforce role-based access control (RBAC) boundaries
          if (location.startsWith('/admin') && !user.isAdmin) {
            return '/employee/dashboard'; // Route back if employee attempts to breach admin screen
          }

          if (location.startsWith('/employee') && user.isAdmin) {
            return '/admin/dashboard'; // Route back if admin goes to employee-only zone
          }

          return null; // Keep current route
        },
        loading: () => isSplash ? null : '/splash',
        error: (_, __) => '/login',
      );
    },

    routes: [
      // Splash Boundary
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashLoadingScreen(),
      ),

      // Auth Boundary
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Admin Boundary (Shell or standard views)
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),

      // Employee Boundary
      GoRoute(
        path: '/employee/dashboard',
        builder: (context, state) => const EmployeeDashboard(),
      ),

      // Employee Leave Route
      GoRoute(
        path: '/employee/leave',
        builder: (context, state) => const EmployeeLeaveScreen(),
      ),

      // Admin Employee Directory Route
      GoRoute(
        path: '/admin/employees',
        builder: (context, state) => const EmployeeDirectoryScreen(),
      ),

      // Admin Add Employee Route
      GoRoute(
        path: '/admin/add-employee',
        builder: (context, state) => const AddEmployeeScreen(),
      ),

      // Admin Employee Details Route
      GoRoute(
        path: '/admin/employee-details',
        builder: (context, state) {
          final employee = state.extra as UserModel;
          return EmployeeDetailsScreen(employee: employee);
        },
      ),

      // Admin Attendance Route
      GoRoute(
        path: '/admin/attendance',
        builder: (context, state) => const AdminAttendanceScreen(),
      ),

      // Admin Attendance Details Route
      GoRoute(
        path: '/admin/attendance-details',
        builder: (context, state) {
          final log = state.extra as AttendanceModel;
          return AttendanceDetailScreen(attendance: log);
        },
      ),

      // Admin/Employee Route History Route
      GoRoute(
        path: '/admin/route-history',
        builder: (context, state) {
          final employeeId = state.uri.queryParameters['employeeId'];
          return LocationHistoryScreen(initialEmployeeId: employeeId);
        },
      ),

      // Generic Coming Soon / Placeholder Route
      GoRoute(
        path: '/coming-soon/:title',
        builder: (context, state) {
          final title = state.pathParameters['title'] ?? 'Coming Soon';
          return ComingSoonScreen(title: title);
        },
      ),
    ],

    // Global Error Screen (404 Fallback)
    errorBuilder: (context, state) => _RouteErrorScreen(error: state.error),
  );
});

// Private Splash screen widget
class _SplashLoadingScreen extends StatelessWidget {
  const _SplashLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          strokeWidth: 3.0,
        ),
      ),
    );
  }
}

class _RouteErrorScreen extends StatelessWidget {
  final Exception? error;
  const _RouteErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Requested destination does not exist.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unknown Routing Exception',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
