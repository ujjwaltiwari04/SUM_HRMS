import 'package:flutter/foundation.dart';

/// Explicit definitions for User Roles allowed inside Sum Enterprises corporate application.
enum UserRole {
  admin,
  employee,
}

/// Domain User model representing corporate entities inside SUM Enterprises.
/// Maximum 1 Admin and 6 Employees. Implements value comparisons for performance.
@immutable
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final String? phoneNumber;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final bool isActive;
  final String designation;
  final String employeeId;
  final DateTime? joiningDate;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.profileImageUrl,
    this.createdAt,
    this.isActive = true,
    this.designation = 'Staff Specialist',
    this.employeeId = '',
    this.joiningDate,
  });

  /// Computed helper to enforce role boundary rules inside routes or controllers
  bool get isAdmin => role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;

  /// Map Firebase NoSQL DocumentSnapshot data directly to typed domain model
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    UserRole parsedRole = UserRole.employee;
    final String? roleStr = map['role'] as String?;
    if (roleStr != null) {
      if (roleStr.toLowerCase() == 'admin') {
        parsedRole = UserRole.admin;
      }
    }

    final empId = map['employeeId'] as String? ?? 'SUM-${documentId.substring(0, documentId.length > 5 ? 5 : documentId.length).toUpperCase()}';

    return UserModel(
      uid: documentId,
      email: map['email'] as String? ?? '',
      fullName: map['name'] as String? ?? map['fullName'] as String? ?? 'Sum Employee',
      role: parsedRole,
      phoneNumber: map['phone'] as String? ?? map['phoneNumber'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      createdAt: map['createdAt'] != null 
          ? DateTime.tryParse(map['createdAt'].toString()) 
          : null,
      isActive: map['isActive'] as bool? ?? true,
      designation: map['designation'] as String? ?? (parsedRole == UserRole.admin ? 'Administrator' : 'Corporate Specialist'),
      employeeId: empId,
      joiningDate: map['joiningDate'] != null 
          ? DateTime.tryParse(map['joiningDate'].toString()) 
          : (map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null),
    );
  }

  /// Serialize domain objects back to JSON format for Cloud Firestore insertions
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': fullName,
      'fullName': fullName,
      'role': role == UserRole.admin ? 'admin' : 'employee',
      'phone': phoneNumber,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt?.toIso8601String(),
      'isActive': isActive,
      'designation': designation,
      'employeeId': employeeId,
      'joiningDate': joiningDate?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    UserRole? role,
    String? phoneNumber,
    String? profileImageUrl,
    DateTime? createdAt,
    bool? isActive,
    String? designation,
    String? employeeId,
    DateTime? joiningDate,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      designation: designation ?? this.designation,
      employeeId: employeeId ?? this.employeeId,
      joiningDate: joiningDate ?? this.joiningDate,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.fullName == fullName &&
        other.role == role &&
        other.phoneNumber == phoneNumber &&
        other.profileImageUrl == profileImageUrl &&
        other.isActive == isActive &&
        other.designation == designation &&
        other.employeeId == employeeId;
  }

  @override
  int get hashCode {
    return Object.hash(
      uid,
      email,
      fullName,
      role,
      phoneNumber,
      profileImageUrl,
      isActive,
      designation,
      employeeId,
    );
  }
}
