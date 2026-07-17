import 'package:sum_enterprises/features/location/domain/models/location_model.dart';

abstract class LocationRepository {
  /// Save a new location update to 'employee_locations' (new record)
  /// and update the employee's latest record in 'employee_last_location'
  Future<void> saveLocationUpdate(LocationModel location);

  /// Stream the latest known location for a specific employee
  Stream<LocationModel?> streamLastLocation(String employeeId);

  /// Stream the latest known locations for all employees
  Stream<List<LocationModel>> streamAllLastLocations();

  /// Stream location history with optional filters for employeeId and date (YYYY-MM-DD)
  Stream<List<LocationModel>> streamLocationHistory({String? employeeId, String? date});

  /// Automatically delete location history older than a specific number of days (e.g. 90 days),
  /// while keeping the latest location permanently.
  Future<void> cleanOldLocationHistory(int daysOlderThan);
}
