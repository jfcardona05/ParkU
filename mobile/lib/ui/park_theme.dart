import 'package:flutter/material.dart';

abstract final class ParkColors {
  static const ink = Color(0xFF171725);
  static const muted = Color(0xFF777783);
  static const background = Color(0xFFF7F7F4);
  static const yellow = Color(0xFFFFDB4D);
  static const green = Color(0xFF227654);
  static const greenLight = Color(0xFFEAF5EE);
}

ThemeData parkTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Manrope',
  brightness: Brightness.light,
  scaffoldBackgroundColor: ParkColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ParkColors.yellow,
    primary: ParkColors.yellow,
    onPrimary: ParkColors.ink,
    surface: Colors.white,
    onSurface: ParkColors.ink,
    error: const Color(0xFFB3261E),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 40,
      height: 1.18,
      fontWeight: FontWeight.w800,
      color: ParkColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 34,
      height: 1.25,
      fontWeight: FontWeight.w800,
      color: ParkColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: ParkColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: ParkColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: ParkColors.ink),
    bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: ParkColors.ink),
    bodySmall: TextStyle(fontSize: 12, height: 1.5, color: ParkColors.muted),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: ParkColors.background,
    foregroundColor: ParkColors.ink,
    elevation: 0,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ParkColors.yellow,
      foregroundColor: ParkColors.ink,
      minimumSize: const Size(48, 74),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: ParkColors.yellow,
      foregroundColor: ParkColors.ink,
      elevation: 0,
      minimumSize: const Size(48, 74),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: ParkColors.ink),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE6E6E3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE6E6E3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ParkColors.ink, width: 1.5),
    ),
  ),
  dividerColor: const Color(0xFFECECE8),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: ParkColors.ink,
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: ParkColors.ink,
    contentTextStyle: TextStyle(color: Colors.white),
  ),
);
