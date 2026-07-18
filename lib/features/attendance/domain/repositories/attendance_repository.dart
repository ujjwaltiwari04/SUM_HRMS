import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';

abstract class AttendanceRepository {
  /// Stream of today's attendance for a specific employee. Emits null if no record exists for today.
  Stream<AttendanceModel?> streamTodayAttendance(String employeeId, String date);

  /// Fetch today's attendance directly (for one-shot validation)
  Future<AttendanceModel?> getTodayAttendance(String employeeId, String date);

  /// Stream of full attendance history for a specific employee sorted by newest first
  Stream<List<AttendanceModel>> streamEmployeeHistory(String employeeId);

  /// Stream of all attendance records for admin (used in dashboard and detailed list)
  Stream<List<AttendanceModel>> streamAllAttendance({String? date, String? employeeId});

  /// Record check-in event
  Future<void> checkIn(AttendanceModel attendance);

  /// Record check-out event
  Future<void> checkOut(String attendanceId, DateTime checkOutTime, double lat, double lng, double accuracy);

  /// Manually override check-in for an employee (admin only)
  Future<void> overrideCheckIn({
    required String employeeId,
    required String employeeName,
    required String date,
    required DateTime checkInTime,
    required String reason,
    required String adminUid,
  });

  /// Manually override check-out for an employee (admin only)
  Future<void> overrideCheckOut({
    required String attendanceId,
    required DateTime checkOutTime,
    required String reason,
    required String adminUid,
  });

  /// Manually override any attendance status (admin only)
  Future<void> overrideAttendance({
    required String employeeId,
    required String employeeName,
    required String date,
    required String status, // 'Present' | 'Absent' | 'Leave' | 'Half Day'
    required String reason,
    required String adminUid,
    DateTime? checkInTime,
    DateTime? checkOutTime,
  });
}
