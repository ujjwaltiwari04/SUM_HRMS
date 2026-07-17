import 'package:flutter/material.dart';

/// Decoupled Color Scheme declarations matching Google Material Design 3 and Sum Enterprises brand guidelines.
/// Primary: Copper Brown (#8B4513)
/// Secondary: Warm Brown (#A05A2C)
/// Background: Light off-white (#FAFAFA)
/// Cards: Full White (#FFFFFF)
class AppColorSchemes {
  static const Color primaryColor = Color(0x8B451300); // Wait, Color in Flutter is 0xFF8B4513, let's write 0xFF8B4513
  static const Color copperBrown = Color(0xFF8B4513);
  static const Color warmBrown = Color(0xFFA05A2C);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color errorRed = Color(0xFFC62828);

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: copperBrown,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFDBCF),
    onPrimaryContainer: Color(0xFF351000),
    secondary: warmBrown,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFDCCF),
    onSecondaryContainer: Color(0xFF381600),
    tertiary: Color(0xFF705C2E),
    onTertiary: Colors.white,
    background: backgroundLight,
    onBackground: Color(0xFF201A18),
    surface: cardWhite,
    onSurface: Color(0xFF201A18),
    surfaceVariant: Color(0xFFF5DED6),
    onSurfaceVariant: Color(0xFF53433E),
    outline: Color(0xFF85736C),
    error: errorRed,
    onError: Colors.white,
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFB59D),
    onPrimary: Color(0xFF561E00),
    primaryContainer: Color(0xFF7A2F00),
    onPrimaryContainer: Color(0xFFFFDBCF),
    secondary: Color(0xFFFFB59E),
    onSecondary: Color(0xFF571E00),
    secondaryContainer: Color(0xFF7D3200),
    onSecondaryContainer: Color(0xFFFFDCCF),
    tertiary: Color(0xFFDEC38B),
    onTertiary: Color(0xFF3E2E04),
    background: Color(0xFF201A18),
    onBackground: Color(0xFFEDE0DC),
    surface: Color(0xFF2A221F),
    onSurface: Color(0xFFEDE0DC),
    surfaceVariant: Color(0xFF53433E),
    onSurfaceVariant: Color(0xFFD8C2BB),
    outline: Color(0xFFA08D86),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
  );
}
