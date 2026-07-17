import 'package:flutter/material.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/core/theme/color_schemes.dart';

/// Centralized Material Design 3 Theme configuration.
/// Applies the customized SpaceGrotesk typography, 14px rounded corners,
/// and Copper and Warm Brown corporate styling.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return _buildTheme(AppColorSchemes.lightColorScheme);
  }

  static ThemeData get darkTheme {
    return _buildTheme(AppColorSchemes.darkColorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final bool isLight = colorScheme.brightness == Brightness.light;
    final Color cardBackground = isLight ? Colors.white : const Color(0xFF231C1A);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      
      // Default Custom Font Family configuration
      fontFamily: AppConstants.fontSans,

      // Elevated and Card Component Styling (14.0px Rounded Corners)
      cardTheme: CardTheme(
        color: cardBackground,
        elevation: AppConstants.defaultElevation,
        shadowColor: Colors.black.withOpacity(0.06),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          side: isLight 
              ? BorderSide(color: colorScheme.outline.withOpacity(0.12), width: 1.0)
              : BorderSide.none,
        ),
      ),

      // Input Field (TextFormField) Styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : const Color(0xFF2F2421),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Button Themes (14.0px Rounded Corners)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: AppConstants.fontSans,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: AppConstants.fontSans,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),

      // AppBar Custom Styling
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.onBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppConstants.fontSans,
          fontWeight: FontWeight.bold,
          fontSize: 20.0,
          color: colorScheme.onBackground,
        ),
        iconTheme: IconThemeData(color: colorScheme.onBackground),
      ),

      // Bottom Navigation Bar configuration
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : const Color(0xFF231C1A),
        indicatorColor: colorScheme.primaryContainer,
        elevation: 4.0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final isSelected = states.contains(MaterialState.selected);
          return TextStyle(
            fontFamily: AppConstants.fontSans,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12.0,
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // Typography Configuration
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: AppConstants.fontSans, fontWeight: FontWeight.bold, fontSize: 32.0),
        displayMedium: TextStyle(fontFamily: AppConstants.fontSans, fontWeight: FontWeight.bold, fontSize: 28.0),
        displaySmall: TextStyle(fontFamily: AppConstants.fontSans, fontWeight: FontWeight.bold, fontSize: 24.0),
        headlineMedium: TextStyle(fontFamily: AppConstants.fontSans, fontWeight: FontWeight.w600, fontSize: 20.0),
        titleMedium: TextStyle(fontFamily: AppConstants.fontSans, fontWeight: FontWeight.w500, fontSize: 16.0),
        bodyLarge: TextStyle(fontFamily: AppConstants.fontSans, fontWeight: FontWeight.normal, fontSize: 16.0),
        bodyMedium: TextStyle(fontFamily: AppConstants.fontSans, fontWeight: FontWeight.normal, fontSize: 14.0),
        labelLarge: TextStyle(fontFamily: AppConstants.fontSans, fontWeight: FontWeight.bold, fontSize: 14.0),
        // Monospace code / meta text styling for telemetry, logs, location pins, timestamps
        bodySmall: TextStyle(fontFamily: AppConstants.fontMono, fontWeight: FontWeight.normal, fontSize: 12.0),
      ),
    );
  }
}
