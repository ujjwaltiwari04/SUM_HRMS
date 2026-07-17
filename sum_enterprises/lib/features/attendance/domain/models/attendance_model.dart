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
  final String? workingHours; // e.g. "2 Hours 18 Minutes"
  final String status; // "Checked In", "Checked Out"
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.workingHours,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

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
      workingHours: map['workingHours'] as String?,
      status: map['status'] as String? ?? 'Checked In',
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
      'workingHours': workingHours,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
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
    String? workingHours,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      workingHours: workingHours ?? this.workingHours,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
