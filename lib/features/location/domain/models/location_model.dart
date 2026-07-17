import 'package:cloud_firestore/cloud_firestore.dart';

/// Representation of a GPS Location update record for a field employee.
class LocationModel {
  final String locationId;
  final String employeeId;
  final String employeeName;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double? speed; // in meters/second
  final int batteryPercentage;
  final String deviceModel;
  final String internetStatus; // "Online" or "Offline"

  const LocationModel({
    required this.locationId,
    required this.employeeId,
    required this.employeeName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    this.speed,
    required this.batteryPercentage,
    required this.deviceModel,
    required this.internetStatus,
  });

  /// Factory constructor mapping from Firestore document map
  factory LocationModel.fromMap(Map<String, dynamic> map, String documentId) {
    return LocationModel(
      locationId: documentId,
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp
              ? (map['timestamp'] as Timestamp).toDate()
              : DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble(),
      batteryPercentage: (map['batteryPercentage'] as num?)?.toInt() ?? 100,
      deviceModel: map['deviceModel'] as String? ?? 'Unknown Device',
      internetStatus: map['internetStatus'] as String? ?? 'Online',
    );
  }

  /// Maps representation for Firestore ingestion
  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'accuracy': accuracy,
      'speed': speed,
      'batteryPercentage': batteryPercentage,
      'deviceModel': deviceModel,
      'internetStatus': internetStatus,
    };
  }

  /// Copy constructor to mutate state immutably
  LocationModel copyWith({
    String? locationId,
    String? employeeId,
    String? employeeName,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? accuracy,
    double? speed,
    int? batteryPercentage,
    String? deviceModel,
    String? internetStatus,
  }) {
    return LocationModel(
      locationId: locationId ?? this.locationId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      deviceModel: deviceModel ?? this.deviceModel,
      internetStatus: internetStatus ?? this.internetStatus,
    );
  }
}
