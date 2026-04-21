import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Ciemniejsza paleta z zielonym akcentem
  static const Color primaryDark   = Color(0xFF0D2137);
  static const Color primaryMid    = Color(0xFF1A4566);
  static const Color primaryLight  = Color(0xFF2878B5);
  static const Color accent        = Color(0xFF22C55E); // zielony akcent
  static const Color accentDark    = Color(0xFF16A34A);
  static const Color background    = Color(0xFFEEF2F7);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color errorRed      = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color successGreen  = Color(0xFF16A34A);
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color borderLight   = Color(0xFFE2E8F0);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryDark,
      primary: primaryDark,
      secondary: accent,
      surface: surface,
      error: errorRed,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,       // ZIELONY przycisk
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryDark,
        side: const BorderSide(color: borderLight, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryMid,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderLight),
      ),
      color: surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: textSecondary),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      labelSmall: TextStyle(color: textSecondary, letterSpacing: 0.08),
    ),
  );
}
