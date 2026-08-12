import 'package:flutter/material.dart';

abstract final class NylaColors {
  static const canvas = Color(0xFFFFF9F7);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF3D3038);
  static const mutedInk = Color(0xFF786A72);
  static const rose = Color(0xFFB65D78);
  static const roseSoft = Color(0xFFF5D4DD);
  static const peach = Color(0xFFF7DDCF);
  static const lavender = Color(0xFFE5DCF0);
  static const sage = Color(0xFFDCE9E0);
  static const outline = Color(0xFFE8DDE1);
  static const warning = Color(0xFF9A5C38);
}

abstract final class NylaTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: NylaColors.rose,
      brightness: Brightness.light,
      surface: NylaColors.canvas,
    ).copyWith(
      primary: NylaColors.rose,
      onPrimary: Colors.white,
      surface: NylaColors.canvas,
      onSurface: NylaColors.ink,
      outline: NylaColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: NylaColors.canvas,
      fontFamilyFallback: const ['SF Pro Rounded', 'SF Pro Display', 'Roboto'],
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: NylaColors.ink,
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
        ),
        headlineMedium: TextStyle(
          color: NylaColors.ink,
          fontSize: 25,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.55,
        ),
        titleLarge: TextStyle(
          color: NylaColors.ink,
          fontSize: 19,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        bodyLarge: TextStyle(color: NylaColors.ink, fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(color: NylaColors.mutedInk, fontSize: 14, height: 1.45),
        labelLarge: TextStyle(color: NylaColors.ink, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      cardTheme: const CardThemeData(
        color: NylaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
          side: BorderSide(color: NylaColors.outline, width: 0.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NylaColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: NylaColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: NylaColors.outline),
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
