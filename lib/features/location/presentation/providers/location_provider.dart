import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/features/auth/domain/models/user_model.dart';
import 'package:sum_enterprises/features/auth/presentation/providers/auth_provider.dart';
import 'package:sum_enterprises/features/attendance/presentation/providers/attendance_provider.dart';
import 'package:sum_enterprises/features/location/domain/models/location_model.dart';
import 'package:sum_enterprises/features/location/domain/repositories/location_repository.dart';
import 'package:sum_enterprises/features/location/data/repositories/location_repository_impl.dart';

/// Provider of LocationRepository adapter
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl();
});

/// Stream provider for specific employee's latest known location
final employeeLastLocationStreamProvider = StreamProvider.family<LocationModel?, String>((ref, employeeId) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.streamLastLocation(employeeId);
});

/// Stream provider for all latest locations (for admin quick-loading dashboard map/lists)
final allLastLocationsStreamProvider = StreamProvider<List<LocationModel>>((ref) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.streamAllLastLocations();
});

/// Stream provider of location history with optional filters
final locationHistoryStreamProvider = StreamProvider.family<List<LocationModel>, ({String? employeeId, String? date})>((ref, filter) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.streamLocationHistory(employeeId: filter.employeeId, date: filter.date);
});

/// Live GPS Tracking controller tracking Checked In employees.
class LiveTrackingService {
  final Ref _ref;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _periodicTimer;
  Position? _lastUploadedPosition;
  DateTime? _lastUploadedTime;
  bool _isTrackingActive = false;

  LiveTrackingService(this._ref) {
    _init();
  }

  void _init() {
    // Reactively watch today's attendance status to start/stop tracking.
    _ref.listen(todayAttendanceStreamProvider, (previous, next) {
      next.when(
        data: (attendance) {
          final isCheckedIn = attendance != null && attendance.status == 'Present' && attendance.checkInTime != null && attendance.checkOutTime == null;
          if (isCheckedIn) {
            _startTracking();
          } else {
            _stopTracking();
          }
        },
        loading: () {},
        error: (_, __) {
          _stopTracking();
        },
      );
    });
  }

  bool get isTrackingActive => _isTrackingActive;

  /// Starts the tracking routine safely
  Future<void> _startTracking() async {
    if (_isTrackingActive) return;

    // Check Geolocator permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _isTrackingActive = true;

    // 1. Position stream subscription with high accuracy & distance filter of 100 meters
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100, // Trigger immediately if moved 100m
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        _handleNewPosition(position);
      },
      onError: (err) {
        // Silent error handling in background to avoid crashing
      },
    );

    // 2. Periodic timer to guarantee updates every 5 minutes even if the employee is stationary
    _periodicTimer = Timer.periodic(
      const Duration(minutes: AppConstants.locationUpdateIntervalMinutes),
      (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          _handleNewPosition(position, isTimerTrigger: true);
        } catch (_) {
          // If fallback fails, try to use last known or previous uploaded
          if (_lastUploadedPosition != null) {
            _handleNewPosition(_lastUploadedPosition!, isTimerTrigger: true);
          }
        }
      },
    );

    // Trigger an immediate initial upload upon starting duty
    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      _handleNewPosition(initialPosition);
    } catch (_) {}
  }

  /// Stops geolocator listeners and background timers immediately
  void _stopTracking() {
    if (!_isTrackingActive) return;
    
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _lastUploadedPosition = null;
    _lastUploadedTime = null;
    _isTrackingActive = false;
  }

  /// Evaluates whether to save location update based on distance (>100m) or time (5 mins) criteria
  Future<void> _handleNewPosition(Position position, {bool isTimerTrigger = false}) async {
    final now = DateTime.now();
    
    if (_lastUploadedPosition != null && _lastUploadedTime != null && !isTimerTrigger) {
      final distance = Geolocator.distanceBetween(
        _lastUploadedPosition!.latitude,
        _lastUploadedPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      final elapsedMinutes = now.difference(_lastUploadedTime!).inMinutes;

      // Only upload if moved > 100 meters OR if 5 minutes have elapsed
      final bool hasMovedFar = distance >= AppConstants.locationUpdateDistanceFilterMeters;
      final bool isTimeElapsed = elapsedMinutes >= AppConstants.locationUpdateIntervalMinutes;

      if (!hasMovedFar && !isTimeElapsed) {
        return; // Skip redundant updates to conserve battery
      }
    }

    _lastUploadedPosition = position;
    _lastUploadedTime = now;

    // Build Location update metadata
    final currentUserAsync = _ref.read(phoneAuthControllerProvider);
    final user = currentUserAsync.user;
    if (user == null) return;

    try {
      final batteryLevel = await _getBatteryPercentage();
      final deviceModel = await _getDeviceModel();
      final internetStatus = await _getInternetStatus();

      final locationModel = LocationModel(
        locationId: '', // Auto-assigned by Firestore collection add
        employeeId: user.uid,
        employeeName: user.fullName,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: now,
        accuracy: position.accuracy,
        speed: position.speed >= 0 ? position.speed : null,
        batteryPercentage: batteryLevel,
        deviceModel: deviceModel,
        internetStatus: internetStatus,
      );

      final repo = _ref.read(locationRepositoryProvider);
      await repo.saveLocationUpdate(locationModel);
      
      // Auto-cleanup historical database older than 90 days silently upon updates
      await repo.cleanOldLocationHistory(90);
    } catch (_) {
      // Gracefully prevent background crash
    }
  }

  Future<int> _getBatteryPercentage() async {
    try {
      return await Battery().batteryLevel;
    } catch (_) {
      return 100;
    }
  }

  Future<String> _getDeviceModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.utsname.machine;
      }
    } catch (_) {}
    return 'Mobile Device';
  }

  Future<String> _getInternetStatus() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result == ConnectivityResult.none ? 'Offline' : 'Online';
    } catch (_) {
      return 'Online';
    }
  }
}

/// Provider of the globally active LiveTrackingService.
/// Initialize this in home layouts or app bootstrap.
final liveTrackingServiceProvider = Provider<LiveTrackingService>((ref) {
  return LiveTrackingService(ref);
});
