import 'package:flutter/material.dart';

/// Centralized application constants used across all features to guarantee uniformity and scale.
class AppConstants {
  // Business Branding
  static const String companyName = 'SUM ENTERPRISES';
  static const String appVersion = '1.0.0';
  
  // Maximum capacity restriction for the internal corporate tool
  static const int maxEmployeesCount = 6;
  static const int maxAdminCount = 1;

  // Shared error messages
  static const String accountDeactivatedMessage = 'Your account has been deactivated. Please contact your administrator.';

  // Firebase Firestore Collection Names
  static const String collectionUsers = 'users';
  static const String collectionAttendance = 'attendance';
  static const String collectionJobs = 'jobs';
  static const String collectionEquipment = 'equipment';
  static const String collectionFCMTokens = 'fcm_tokens';
  static const String collectionEmployeeLocations = 'employee_locations';
  static const String collectionEmployeeLastLocation = 'employee_last_location';

  // Live GPS Tracking Constants
  static const int locationUpdateIntervalMinutes = 5;
  static const double locationUpdateDistanceFilterMeters = 100.0;

  // Shared Preferences & Local Cache Keys
  static const String keyUserRole = 'cached_user_role';
  static const String keyUserToken = 'cached_user_token';
  static const String keyLocalSettings = 'cached_local_settings';

  // Default Location Coordinates for Google Maps (Corporate HQ Example)
  // Can be centered where Sum Enterprises operates.
  static const double defaultLat = 37.774929;
  static const double defaultLng = -122.419416;
  
  // Visual Alignment Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 14.0; // Corporate mandated 14px rounded corners
  static const double defaultIconSize = 24.0;
  static const double defaultElevation = 2.0; // Soft shadow elevation

  // Typography Family (Fallback to system defaults since TTF assets are missing)
  static const String fontSans = '';
  static const String fontMono = '';
}
