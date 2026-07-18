import 'package:sum_enterprises/features/attendance/domain/models/leave_request_model.dart';

abstract class LeaveRepository {
  /// Stream of all pending leave requests for the admin view
  Stream<List<LeaveRequestModel>> streamPendingLeaves();

  /// Stream of all leave requests (Pending, Approved, Rejected, Cancelled) for a specific employee
  Stream<List<LeaveRequestModel>> streamEmployeeLeaves(String employeeUid);

  /// Apply for a new leave request (employee action)
  Future<void> applyLeave(LeaveRequestModel leave);

  /// Cancel a pending leave request (employee action). 
  /// Only pending requests can be cancelled. Once cancelled, it transitions to LeaveStatus.cancelled
  Future<void> cancelLeave(String leaveId);

  /// Approve a leave request (admin action).
  /// This performs a transaction that updates the leave status and automatically populates the
  /// corresponding attendance records for the dates in the range.
  Future<void> approveLeave({
    required String leaveId,
    required String adminUid,
    String? adminComment,
  });

  /// Reject a leave request (admin action).
  /// This updates the leave status and stores the admin comment. No attendance records are written.
  Future<void> rejectLeave({
    required String leaveId,
    required String adminUid,
    String? adminComment,
  });
}
