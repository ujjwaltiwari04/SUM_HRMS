import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveType {
  fullDay,
  halfDay,
}

enum LeaveStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

enum HalfDayPeriod {
  morning,
  afternoon,
}

class LeaveRequestModel {
  final String leaveId;
  final String employeeUid;
  final LeaveType type;
  final HalfDayPeriod? halfDayPeriod;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveStatus status;
  final String? adminComment;
  final DateTime appliedAt;
  final DateTime? processedAt;
  final String? processedBy;

  const LeaveRequestModel({
    required this.leaveId,
    required this.employeeUid,
    required this.type,
    this.halfDayPeriod,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.adminComment,
    required this.appliedAt,
    this.processedAt,
    this.processedBy,
  });

  /// Factory constructor mapping from Firestore Document Map
  factory LeaveRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    // Parse Leave Type
    LeaveType parsedType = LeaveType.fullDay;
    final typeStr = map['type'] as String?;
    if (typeStr != null && typeStr.toLowerCase() == 'half day') {
      parsedType = LeaveType.halfDay;
    }

    // Parse Half Day Period
    HalfDayPeriod? parsedPeriod;
    final periodStr = map['halfDayPeriod'] as String?;
    if (periodStr != null) {
      if (periodStr.toLowerCase() == 'morning') {
        parsedPeriod = HalfDayPeriod.morning;
      } else if (periodStr.toLowerCase() == 'afternoon') {
        parsedPeriod = HalfDayPeriod.afternoon;
      }
    }

    // Parse Leave Status
    LeaveStatus parsedStatus = LeaveStatus.pending;
    final statusStr = map['status'] as String?;
    if (statusStr != null) {
      final normalized = statusStr.toLowerCase();
      if (normalized == 'approved') {
        parsedStatus = LeaveStatus.approved;
      } else if (normalized == 'rejected') {
        parsedStatus = LeaveStatus.rejected;
      } else if (normalized == 'cancelled') {
        parsedStatus = LeaveStatus.cancelled;
      }
    }

    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return LeaveRequestModel(
      leaveId: docId,
      employeeUid: map['employeeUid'] as String? ?? '',
      type: parsedType,
      halfDayPeriod: parsedPeriod,
      startDate: parseDateTime(map['startDate']),
      endDate: parseDateTime(map['endDate']),
      reason: map['reason'] as String? ?? '',
      status: parsedStatus,
      adminComment: map['adminComment'] as String?,
      appliedAt: parseDateTime(map['appliedAt']),
      processedAt: map['processedAt'] != null ? parseDateTime(map['processedAt']) : null,
      processedBy: map['processedBy'] as String?,
    );
  }

  /// Serialize domain objects back to Map for Cloud Firestore
  Map<String, dynamic> toMap() {
    return {
      'employeeUid': employeeUid,
      'type': type == LeaveType.fullDay ? 'Full Day' : 'Half Day',
      'halfDayPeriod': halfDayPeriod == null
          ? null
          : (halfDayPeriod == HalfDayPeriod.morning ? 'Morning' : 'Afternoon'),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'reason': reason,
      'status': status == LeaveStatus.pending
          ? 'Pending'
          : (status == LeaveStatus.approved
              ? 'Approved'
              : (status == LeaveStatus.rejected ? 'Rejected' : 'Cancelled')),
      'adminComment': adminComment,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processedBy': processedBy,
    };
  }

  LeaveRequestModel copyWith({
    String? leaveId,
    String? employeeUid,
    LeaveType? type,
    HalfDayPeriod? halfDayPeriod,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    LeaveStatus? status,
    String? adminComment,
    DateTime? appliedAt,
    DateTime? processedAt,
    String? processedBy,
  }) {
    return LeaveRequestModel(
      leaveId: leaveId ?? this.leaveId,
      employeeUid: employeeUid ?? this.employeeUid,
      type: type ?? this.type,
      halfDayPeriod: halfDayPeriod ?? this.halfDayPeriod,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      adminComment: adminComment ?? this.adminComment,
      appliedAt: appliedAt ?? this.appliedAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
    );
  }
}
