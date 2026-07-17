import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sum_enterprises/core/routing/app_router.dart';
import 'package:sum_enterprises/core/theme/app_theme.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/features/location/presentation/providers/location_provider.dart';

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
