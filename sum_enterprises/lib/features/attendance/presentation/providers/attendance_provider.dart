import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/auth/presentation/providers/auth_provider.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';
import 'package:sum_enterprises/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:sum_enterprises/features/attendance/data/repositories/attendance_repository_impl.dart';

/// Provider of AttendanceRepository adapter
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl();
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

  AttendanceActionController({
    required AttendanceRepository repository,
    required UserModel? currentUser,
  })  : _repository = repository,
        _currentUser = currentUser,
        super(const AttendanceActionState());

  /// Triggers full check in workflow
  Future<bool> checkIn() async {
    if (_currentUser == null) {
      state = state.copyWith(errorMessage: 'Authentication session expired. Please re-login.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
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
        status: 'Checked In',
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
        workingHoursStr,
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
  return AttendanceActionController(repository: repo, currentUser: user);
});
