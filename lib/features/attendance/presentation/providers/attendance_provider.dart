import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sum_enterprises/core/services/account_status_guard.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/auth/presentation/providers/auth_provider.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';
import 'package:sum_enterprises/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:sum_enterprises/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sum_enterprises/features/employee/presentation/providers/employee_provider.dart';
import 'package:sum_enterprises/features/attendance/domain/models/leave_request_model.dart';
import 'package:sum_enterprises/features/attendance/domain/repositories/leave_repository.dart';
import 'package:sum_enterprises/features/attendance/data/repositories/leave_repository_impl.dart';

/// Provider of AttendanceRepository adapter
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl();
});

/// Provider of LeaveRepository adapter
final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepositoryImpl();
});

/// Reactive stream of all pending leave requests for admin
final pendingLeavesStreamProvider = StreamProvider<List<LeaveRequestModel>>((ref) {
  final repo = ref.watch(leaveRepositoryProvider);
  return repo.streamPendingLeaves();
});

/// Reactive family stream of leave requests for a specific employee
final employeeLeavesStreamProvider = StreamProvider.family<List<LeaveRequestModel>, String>((ref, employeeUid) {
  final repo = ref.watch(leaveRepositoryProvider);
  return repo.streamEmployeeLeaves(employeeUid);
});

/// Reactive stream of today's attendance for the logged-in employee
final todayAttendanceStreamProvider = StreamProvider<AttendanceModel?>((ref) {
  final user = ref.watch(phoneAuthControllerProvider).user;
  if (user == null) {
    return Stream.value(null);
  }
  
  final repo = ref.watch(attendanceRepositoryProvider);
  final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return repo.streamTodayAttendance(user.uid, todayDate);
});

/// Reactive stream of attendance history for the logged-in employee
final employeeAttendanceHistoryProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final user = ref.watch(phoneAuthControllerProvider).user;
  if (user == null) {
    return Stream.value([]);
  }

  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.streamEmployeeHistory(user.uid);
});

/// Reactive stream of ALL attendance records for admin, allowing filtering
final adminAttendanceListProvider = StreamProvider.family<List<AttendanceModel>, ({String? date, String? employeeId})>((ref, filter) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.streamAllAttendance(date: filter.date, employeeId: filter.employeeId);
});

/// State for checking-in and checking-out actions
class AttendanceActionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const AttendanceActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  AttendanceActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AttendanceActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// StateNotifier controller orchestrating GPS constraints & Firebase transactions
class AttendanceActionController extends StateNotifier<AttendanceActionState> {
  final AttendanceRepository _repository;
  final UserModel? _currentUser;
  final AccountStatusGuard _statusGuard;

  AttendanceActionController({
    required AttendanceRepository repository,
    required UserModel? currentUser,
    required AccountStatusGuard statusGuard,
  })  : _repository = repository,
        _currentUser = currentUser,
        _statusGuard = statusGuard,
        super(const AttendanceActionState());

  /// Triggers full check in workflow
  Future<bool> checkIn() async {
    if (_currentUser == null) {
      state = state.copyWith(errorMessage: 'Authentication session expired. Please re-login.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      // Reusable account status check
      await _statusGuard.validateActiveStatus(_currentUser!.uid);

      // 1. Check Internet Connection
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection. Active network connection is required.');
      }

      // 2 & 3. Check & Request Location Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Accurate GPS tracking is required for validation.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable location services in Settings.');
      }

      // 4. Check GPS Enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('GPS is disabled. Please enable device location services.');
      }

      // 5. Get current location
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (e) {
        // Fallback or retry with lower accuracy if timeout/failure occurs
        try {
          position = await Geolocator.getLastKnownPosition() ?? 
              await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
                timeLimit: const Duration(seconds: 8),
              );
        } catch (_) {
          throw Exception('Location acquisition timed out. Please stand under clear sky and retry.');
        }
      }

      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Prevent duplicate check-in at client layer (just in case)
      final existingRecord = await _repository.getTodayAttendance(_currentUser!.uid, todayDate);
      if (existingRecord != null) {
        throw Exception('You have already completed check-in for today.');
      }

      // 6 & 7. Save attendance in Firestore
      final attendance = AttendanceModel(
        attendanceId: '${_currentUser!.uid}_$todayDate',
        employeeId: _currentUser!.uid,
        employeeName: _currentUser!.fullName,
        date: todayDate,
        checkInTime: DateTime.now(),
        checkInLatitude: position.latitude,
        checkInLongitude: position.longitude,
        checkInAccuracy: position.accuracy,
        status: 'Present',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.checkIn(attendance);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully checked in with high GPS accuracy (${position.accuracy.toStringAsFixed(1)}m)!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Triggers full check out workflow
  Future<bool> checkOut(AttendanceModel todayAttendance) async {
    if (_currentUser == null) {
      state = state.copyWith(errorMessage: 'Authentication session expired.');
      return false;
    }

    if (todayAttendance.status == 'Checked Out') {
      state = state.copyWith(errorMessage: 'You have already checked out for today.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      // Reusable account status check
      await _statusGuard.validateActiveStatus(_currentUser!.uid);

      // 1. Check Internet Connection
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection. Active network connection is required.');
      }

      // 2 & 3. Check & Request Location Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Accurate GPS tracking is required.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // 4. Check GPS Enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('GPS is disabled. Please enable device location services.');
      }

      // 5. Get current location
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (e) {
        try {
          position = await Geolocator.getLastKnownPosition() ?? 
              await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
                timeLimit: const Duration(seconds: 8),
              );
        } catch (_) {
          throw Exception('Location acquisition timed out. Please stand under clear sky and retry.');
        }
      }

      final checkOutTime = DateTime.now();
      final checkInTime = todayAttendance.checkInTime ?? DateTime.now();

      // Calculate working duration
      final difference = checkOutTime.difference(checkInTime);
      final hours = difference.inHours;
      final minutes = difference.inMinutes.remainder(60);
      final workingHoursStr = hours == 0 
          ? '$minutes Minutes' 
          : '$hours Hours $minutes Minutes';

      // 6. Update in Firestore
      await _repository.checkOut(
        todayAttendance.attendanceId,
        checkOutTime,
        position.latitude,
        position.longitude,
        position.accuracy,
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully checked out! Shift duration: $workingHoursStr.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

/// Provider of AttendanceActionController
final attendanceActionControllerProvider = StateNotifierProvider<AttendanceActionController, AttendanceActionState>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  final user = ref.watch(phoneAuthControllerProvider).user;
  final statusGuard = ref.watch(accountStatusGuardProvider);
  return AttendanceActionController(
    repository: repo,
    currentUser: user,
    statusGuard: statusGuard,
  );
});

/// Reactive stream of today's attendance for a specific employee
final employeeTodayAttendanceStreamProvider = StreamProvider.family<AttendanceModel?, String>((ref, employeeId) {
  final repo = ref.watch(attendanceRepositoryProvider);
  final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return repo.streamTodayAttendance(employeeId, todayDate);
});

/// State representing the manual administrator override actions
class AdminAttendanceOverrideState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const AdminAttendanceOverrideState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  AdminAttendanceOverrideState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AdminAttendanceOverrideState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Controller for manual attendance override actions by system administrators.
class AdminAttendanceOverrideController extends StateNotifier<AdminAttendanceOverrideState> {
  final AttendanceRepository _repository;
  final String? _currentAdminUid;

  AdminAttendanceOverrideController({
    required AttendanceRepository repository,
    required String? currentAdminUid,
  })  : _repository = repository,
        _currentAdminUid = currentAdminUid,
        super(const AdminAttendanceOverrideState());

  /// Overrides the check-in event for a specific employee
  Future<bool> overrideCheckIn({
    required String employeeId,
    required String employeeName,
    required String date,
    required DateTime checkInTime,
    required String reason,
  }) async {
    if (_currentAdminUid == null) {
      state = state.copyWith(errorMessage: 'Admin session expired. Please re-login.');
      return false;
    }

    if (reason.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter a valid reason for manual override.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      // Uniqueness check: verify if the employee has already checked in for today
      final existing = await _repository.getTodayAttendance(employeeId, date);
      if (existing != null) {
        throw Exception('Employee has already checked in for today ($date).');
      }

      await _repository.overrideCheckIn(
        employeeId: employeeId,
        employeeName: employeeName,
        date: date,
        checkInTime: checkInTime,
        reason: reason,
        adminUid: _currentAdminUid!,
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Manually checked in employee $employeeName successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Overrides the check-out event for a specific employee
  Future<bool> overrideCheckOut({
    required String employeeId,
    required String date,
    required DateTime checkOutTime,
    required String reason,
  }) async {
    if (_currentAdminUid == null) {
      state = state.copyWith(errorMessage: 'Admin session expired. Please re-login.');
      return false;
    }

    if (reason.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter a valid reason for manual override.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      // Validate that an active check-in exists first
      final existing = await _repository.getTodayAttendance(employeeId, date);
      if (existing == null) {
        throw Exception('No active check-in record exists for today. Manual check-in is required first.');
      }

      if (existing.checkOutTime != null) {
        throw Exception('Employee has already checked out for today.');
      }

      final checkInTime = existing.checkInTime ?? DateTime.now();
      if (checkOutTime.isBefore(checkInTime)) {
        throw Exception('Override check-out time cannot be before the check-in time ($checkInTime).');
      }

      await _repository.overrideCheckOut(
        attendanceId: existing.attendanceId,
        checkOutTime: checkOutTime,
        reason: reason,
        adminUid: _currentAdminUid!,
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Manually checked out employee successfully.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Unified attendance override for Present, Absent, Leave, or Half Day status (admin only)
  Future<bool> overrideAttendance({
    required String employeeId,
    required String employeeName,
    required String date,
    required String status,
    required String reason,
    DateTime? checkInTime,
    DateTime? checkOutTime,
  }) async {
    if (_currentAdminUid == null) {
      state = state.copyWith(errorMessage: 'Admin session expired. Please re-login.');
      return false;
    }

    if (reason.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter a valid reason for manual override.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      await _repository.overrideAttendance(
        employeeId: employeeId,
        employeeName: employeeName,
        date: date,
        status: status,
        reason: reason,
        adminUid: _currentAdminUid!,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
      );

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Manually overridden attendance to status $status.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

/// Provider of AdminAttendanceOverrideController
final adminAttendanceOverrideControllerProvider = StateNotifierProvider<AdminAttendanceOverrideController, AdminAttendanceOverrideState>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  final user = ref.watch(phoneAuthControllerProvider).user;
  return AdminAttendanceOverrideController(
    repository: repo,
    currentAdminUid: user?.uid,
  );
});

/// State for applying, cancelling, approving, and rejecting leave requests
class LeaveActionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const LeaveActionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  LeaveActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return LeaveActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Controller managing leave actions for employees and admins
class LeaveActionController extends StateNotifier<LeaveActionState> {
  final LeaveRepository _repository;
  final String? _currentUserUid;

  LeaveActionController({
    required LeaveRepository repository,
    required String? currentUserUid,
  })  : _repository = repository,
        _currentUserUid = currentUserUid,
        super(const LeaveActionState());

  /// Apply for leave request (employee)
  Future<bool> applyLeave({
    required LeaveType type,
    HalfDayPeriod? halfDayPeriod,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    if (_currentUserUid == null) {
      state = state.copyWith(errorMessage: 'Authentication session expired. Please re-login.');
      return false;
    }

    if (reason.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter a valid reason for applying leave.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      final docId = FirebaseFirestore.instance.collection('leaves').doc().id;
      final leave = LeaveRequestModel(
        leaveId: docId,
        employeeUid: _currentUserUid!,
        type: type,
        halfDayPeriod: halfDayPeriod,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        status: LeaveStatus.pending,
        appliedAt: DateTime.now(),
      );

      await _repository.applyLeave(leave);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully submitted leave request.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Cancel leave request (employee)
  Future<bool> cancelLeave(String leaveId) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      await _repository.cancelLeave(leaveId);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully cancelled leave request.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Approve leave request (admin)
  Future<bool> approveLeave({
    required String leaveId,
    String? adminComment,
  }) async {
    if (_currentUserUid == null) {
      state = state.copyWith(errorMessage: 'Admin session expired. Please re-login.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      await _repository.approveLeave(
        leaveId: leaveId,
        adminUid: _currentUserUid!,
        adminComment: adminComment,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully approved leave request.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Reject leave request (admin)
  Future<bool> rejectLeave({
    required String leaveId,
    String? adminComment,
  }) async {
    if (_currentUserUid == null) {
      state = state.copyWith(errorMessage: 'Admin session expired. Please re-login.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      await _repository.rejectLeave(
        leaveId: leaveId,
        adminUid: _currentUserUid!,
        adminComment: adminComment,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully rejected leave request.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

/// Provider of LeaveActionController
final leaveActionControllerProvider = StateNotifierProvider<LeaveActionController, LeaveActionState>((ref) {
  final repo = ref.watch(leaveRepositoryProvider);
  final user = ref.watch(phoneAuthControllerProvider).user;
  return LeaveActionController(
    repository: repo,
    currentUserUid: user?.uid,
  );
});

/// Unified model representing a row in the admin daily attendance dashboard list
class EmployeeAttendanceRow {
  final UserModel employee;
  final AttendanceModel attendance;

  const EmployeeAttendanceRow({
    required this.employee,
    required this.attendance,
  });
}

/// Reactive combined provider merging employees and their daily attendance status, sorted by priority.
final adminDailyAttendanceProvider = Provider.family<List<EmployeeAttendanceRow>, String>((ref, dateStr) {
  // Watch employee list and daily attendance logs
  final employees = ref.watch(employeeListStreamProvider).value ?? [];
  final attendanceLogs = ref.watch(adminAttendanceListProvider((date: dateStr, employeeId: null))).value ?? [];

  final List<EmployeeAttendanceRow> rows = [];
  for (final emp in employees) {
    // Exclude administrators from the list
    if (emp.isAdmin) continue;

    final log = attendanceLogs.firstWhere(
      (a) => a.employeeId == emp.uid,
      orElse: () {
        // Dynamic absence computation
        return AttendanceModel(
          attendanceId: '${emp.uid}_$dateStr',
          employeeId: emp.uid,
          employeeName: emp.fullName,
          date: dateStr,
          status: 'Absent',
        );
      },
    );
    rows.add(EmployeeAttendanceRow(employee: emp, attendance: log));
  }

  // Sort: Present (1) -> Half Day (2) -> Absent (3) -> Leave (4)
  int getStatusPriority(String status) {
    switch (status) {
      case 'Present':
        return 1;
      case 'Half Day':
        return 2;
      case 'Absent':
        return 3;
      case 'Leave':
        return 4;
      default:
        return 5;
    }
  }

  rows.sort((a, b) {
    final priorityA = getStatusPriority(a.attendance.status);
    final priorityB = getStatusPriority(b.attendance.status);
    return priorityA.compareTo(priorityB);
  });

  return rows;
});
