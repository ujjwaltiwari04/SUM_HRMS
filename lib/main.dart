import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sum_enterprises/core/routing/app_router.dart';
import 'package:sum_enterprises/core/theme/app_theme.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/features/location/presentation/providers/location_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  // Run the app inside a runZonedGuarded block to catch asynchronous boundary exceptions
  runZonedGuarded(() async {
    // Guard the main entrypoint for asynchronous initializations
    WidgetsFlutterBinding.ensureInitialized();

    // Implement structured global error tracking for production
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logGlobalError(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _logGlobalError(error, stack);
      return true; // Error was handled
    };
    // 1. Initialize Firebase Services
    try {
      // In a real Android production environment, compile-time configurations 
      // are auto-injected by firebase_core from google-services.json.
      await Firebase.initializeApp();
      debugPrint('Firebase Core successfully initialized.');
    } catch (e, stack) {
      debugPrint('Error initializing Firebase Core default configuration: $e');
      debugPrint('Attempting to initialize Firebase programmatically with fallback options...');
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyDummyKeyForLocalCompilationPurposeOnly",
            appId: "1:1234567890:android:abcdef123456",
            messagingSenderId: "1234567890",
            projectId: "sum-enterprises-mock",
          ),
        );
        debugPrint('Firebase Core successfully initialized with programmatic fallback.');
      } catch (innerError) {
        debugPrint('Firebase Core programmatic fallback failed: $innerError');
        _logGlobalError(innerError, stack);
      }
      _logGlobalError(e, stack);
    }

    // 1.5. Seed Default Admin User if not already present
    try {
      await _seedDefaultAdmin();
    } catch (e) {
      debugPrint('Error seeding default admin user: $e');
    }

    // 2. Start application wrapped in ProviderScope for Riverpod State Management & DI
    runApp(
      const ProviderScope(
        child: SumEnterprisesApp(),
      ),
    );
  }, (error, stack) {
    _logGlobalError(error, stack);
  });
}

/// Global Error Logger - could be routed to Crashlytics, Sentry or local file logs in future.
void _logGlobalError(Object error, StackTrace? stack) {
  debugPrint('--- CRITICAL UNHANDLED EXCEPTION ---');
  debugPrint('Error: $error');
  if (stack != null) {
    debugPrint('StackTrace: $stack');
  }
  debugPrint('------------------------------------');
}

/// Root Application Widget configured with GoRouter, Material 3 Theme, and corporate branding.
class SumEnterprisesApp extends ConsumerWidget {
  const SumEnterprisesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the background live tracking service reactively
    ref.read(liveTrackingServiceProvider);

    // Watch our declarative router state notifier
    final router = ref.watch(appRouterPro);

    return MaterialApp.router(
      title: AppConstants.companyName,
      debugShowCheckedModeBanner: false,
      
      // Routing Infrastructure
      routerConfig: router,

      // Material 3 Brand Themes
      themeMode: ThemeMode.light, // Default light as requested for Google corporate style
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
    );
  }
}

/// Automatically seeds the default admin user with phone number +918586097283 if not already in database.
Future<void> _seedDefaultAdmin() async {
  final firestore = FirebaseFirestore.instance;
  const phone = '+918586097283';

  // Check if admin already exists by phone
  final query = await firestore
      .collection('users')
      .where('phone', isEqualTo: phone)
      .limit(1)
      .get();

  if (query.docs.isEmpty) {
    // Also check alternate phone field
    final queryAlt = await firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();

    if (queryAlt.docs.isEmpty) {
      debugPrint('Seeding default admin user with phone: $phone');
      // Create user document with phone number
      final docRef = firestore.collection('users').doc('default_admin_uid');
      await docRef.set({
        'email': 'admin@sumenterprises.com',
        'name': 'Default Admin',
        'fullName': 'Default Admin',
        'role': 'admin',
        'phone': phone,
        'phoneNumber': phone,
        'isActive': true,
        'designation': 'System Administrator',
        'employeeId': 'SUM-ADMIN',
        'createdAt': DateTime.now().toIso8601String(),
        'joiningDate': DateTime.now().toIso8601String(),
      });
      debugPrint('Default admin user successfully seeded.');
    } else {
      debugPrint('Default admin already exists under phoneNumber field.');
    }
  } else {
    debugPrint('Default admin already exists under phone field.');
  }
}
