import 'package:cloud_firestore/cloud_firestore.dart';

/// Representation of GPS-based Attendance Record for field employees
class AttendanceModel {
  final String attendanceId;
  final String employeeId;
  final String employeeName;
  final String date; // YYYY-MM-DD
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final double? checkInAccuracy;
  final double? checkOutAccuracy;
  final String status; // "Present", "Absent", "Leave", "Half Day"
  final String? leaveId; // References approved leave request if created from a leave
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Admin Override Audit Fields
  final String? source; // "admin" if overridden by admin
  final String? overriddenBy; // Admin UID
  final String? overrideReason; // Audit reason for manual override
  final DateTime? overrideTimestamp; // Time when manual override took place

  const AttendanceModel({
    required this.attendanceId,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkInAccuracy,
    this.checkOutAccuracy,
    required this.status,
    this.leaveId,
    this.createdAt,
    this.updatedAt,
    this.source,
    this.overriddenBy,
    this.overrideReason,
    this.overrideTimestamp,
  });

  /// Dynamically computes working hours from check-in and check-out timestamps
  String? get workingHours {
    if (checkInTime == null || checkOutTime == null) return null;
    final difference = checkOutTime!.difference(checkInTime!);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    return hours == 0 ? '$minutes Minutes' : '$hours Hours $minutes Minutes';
  }

  /// Factory constructors mapping from Firestore Document
  factory AttendanceModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AttendanceModel(
      attendanceId: documentId,
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      date: map['date'] as String? ?? '',
      checkInTime: map['checkInTime'] != null 
          ? (map['checkInTime'] is Timestamp 
              ? (map['checkInTime'] as Timestamp).toDate() 
              : DateTime.tryParse(map['checkInTime'].toString()))
          : null,
      checkOutTime: map['checkOutTime'] != null
          ? (map['checkOutTime'] is Timestamp 
              ? (map['checkOutTime'] as Timestamp).toDate() 
              : DateTime.tryParse(map['checkOutTime'].toString()))
          : null,
      checkInLatitude: (map['checkInLatitude'] as num?)?.toDouble(),
      checkInLongitude: (map['checkInLongitude'] as num?)?.toDouble(),
      checkOutLatitude: (map['checkOutLatitude'] as num?)?.toDouble(),
      checkOutLongitude: (map['checkOutLongitude'] as num?)?.toDouble(),
      checkInAccuracy: (map['checkInAccuracy'] as num?)?.toDouble(),
      checkOutAccuracy: (map['checkOutAccuracy'] as num?)?.toDouble(),
      status: map['status'] as String? ?? 'Present',
      leaveId: map['leaveId'] as String?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp 
              ? (map['createdAt'] as Timestamp).toDate() 
              : DateTime.tryParse(map['createdAt'].toString()))
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp 
              ? (map['updatedAt'] as Timestamp).toDate() 
              : DateTime.tryParse(map['updatedAt'].toString()))
          : null,
      source: map['source'] as String?,
      overriddenBy: map['overriddenBy'] as String?,
      overrideReason: map['overrideReason'] as String?,
      overrideTimestamp: map['overrideTimestamp'] != null
          ? (map['overrideTimestamp'] is Timestamp 
              ? (map['overrideTimestamp'] as Timestamp).toDate() 
              : DateTime.tryParse(map['overrideTimestamp'].toString()))
          : null,
    );
  }

  /// Maps representation for Firestore ingestion
  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': date,
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'checkInLatitude': checkInLatitude,
      'checkInLongitude': checkInLongitude,
      'checkOutLatitude': checkOutLatitude,
      'checkOutLongitude': checkOutLongitude,
      'checkInAccuracy': checkInAccuracy,
      'checkOutAccuracy': checkOutAccuracy,
      'status': status,
      'leaveId': leaveId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'source': source,
      'overriddenBy': overriddenBy,
      'overrideReason': overrideReason,
      'overrideTimestamp': overrideTimestamp != null ? Timestamp.fromDate(overrideTimestamp!) : null,
    };
  }

  /// Copy constructor to mutate state immutably inside Riverpod providers or streams
  AttendanceModel copyWith({
    String? attendanceId,
    String? employeeId,
    String? employeeName,
    String? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? checkInLatitude,
    double? checkInLongitude,
    double? checkOutLatitude,
    double? checkOutLongitude,
    double? checkInAccuracy,
    double? checkOutAccuracy,
    String? status,
    String? leaveId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
    String? overriddenBy,
    String? overrideReason,
    DateTime? overrideTimestamp,
  }) {
    return AttendanceModel(
      attendanceId: attendanceId ?? this.attendanceId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
      checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
      checkInAccuracy: checkInAccuracy ?? this.checkInAccuracy,
      checkOutAccuracy: checkOutAccuracy ?? this.checkOutAccuracy,
      status: status ?? this.status,
      leaveId: leaveId ?? this.leaveId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      overriddenBy: overriddenBy ?? this.overriddenBy,
      overrideReason: overrideReason ?? this.overrideReason,
      overrideTimestamp: overrideTimestamp ?? this.overrideTimestamp,
    );
  }
}
