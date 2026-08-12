import 'package:flutter/material.dart';

abstract final class NylaColors {
  static const canvas = Color(0xFFFAF6FB);
  static const cream = Color(0xFFFFFCFA);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF241B2B);
  static const mutedInk = Color(0xFF6F6378);
  static const faintInk = Color(0xFFA89AAA);

  static const night = Color(0xFF20172A);
  static const wine = Color(0xFF472A51);
  static const violet = Color(0xFF7056A3);
  static const iris = Color(0xFF8B6FC0);
  static const rose = Color(0xFFB65378);
  static const coral = Color(0xFFE27E83);
  static const roseSoft = Color(0xFFF3C9D8);
  static const roseWash = Color(0xFFF9E7EE);
  static const peach = Color(0xFFF1B993);
  static const peachSoft = Color(0xFFFBE4D5);
  static const lavender = Color(0xFFCAB9E7);
  static const lavenderSoft = Color(0xFFEFE8F8);
  static const lavenderMist = Color(0xFFF6F1FB);
  static const sage = Color(0xFFB9D1C4);
  static const sageSoft = Color(0xFFE5F0E9);
  static const butter = Color(0xFFEBD18B);

  static const outline = Color(0xFFE9DFEB);
  static const warning = Color(0xFF955C44);
}

abstract final class NylaTheme {
  static const _rounded = 'sans-serif-rounded';
  static const _fallback = <String>['sans-serif', 'Roboto'];

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: NylaColors.violet,
      brightness: Brightness.light,
      surface: NylaColors.canvas,
    ).copyWith(
      primary: NylaColors.violet,
      onPrimary: Colors.white,
      secondary: NylaColors.rose,
      onSecondary: Colors.white,
      tertiary: NylaColors.peach,
      surface: NylaColors.canvas,
      onSurface: NylaColors.ink,
      outline: NylaColors.outline,
      surfaceContainerHighest: NylaColors.lavenderSoft,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: NylaColors.canvas,
      splashFactory: InkRipple.splashFactory,
    );

    TextStyle rounded({
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.2,
      double spacing = 0,
    }) => TextStyle(
          fontFamily: _rounded,
          fontFamilyFallback: _fallback,
          color: color,
          fontSize: size,
          height: height,
          fontWeight: weight,
          letterSpacing: spacing,
        );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: rounded(
          size: 39,
          weight: FontWeight.w800,
          color: NylaColors.ink,
          height: 1.02,
          spacing: -1.15,
        ),
        headlineMedium: rounded(
          size: 30,
          weight: FontWeight.w800,
          color: NylaColors.ink,
          height: 1.07,
          spacing: -0.72,
        ),
        titleLarge: rounded(
          size: 20,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.17,
          spacing: -0.18,
        ),
        titleMedium: rounded(
          size: 16,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.22,
          spacing: -0.08,
        ),
        bodyLarge: rounded(
          size: 16,
          weight: FontWeight.w400,
          color: NylaColors.ink,
          height: 1.5,
          spacing: -0.02,
        ),
        bodyMedium: rounded(
          size: 14,
          weight: FontWeight.w400,
          color: NylaColors.mutedInk,
          height: 1.48,
        ),
        labelLarge: rounded(
          size: 14,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.12,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: NylaColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: rounded(
          size: 21,
          weight: FontWeight.w800,
          color: NylaColors.ink,
          height: 1.1,
          spacing: -0.25,
        ),
      ),
      cardTheme: const CardThemeData(
        color: NylaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NylaColors.wine,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
          textStyle: rounded(
            size: 14,
            weight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NylaColors.violet,
          textStyle: rounded(
            size: 14,
            weight: FontWeight.w700,
            color: NylaColors.violet,
            height: 1.1,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.72),
        selectedColor: NylaColors.wine,
        secondarySelectedColor: NylaColors.wine,
        labelStyle: rounded(
          size: 12.5,
          weight: FontWeight.w600,
          color: NylaColors.ink,
          height: 1.05,
        ),
        secondaryLabelStyle: rounded(
          size: 12.5,
          weight: FontWeight.w700,
          color: Colors.white,
          height: 1.05,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.82),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: rounded(
          size: 14,
          weight: FontWeight.w400,
          color: NylaColors.faintInk,
          height: 1.2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: NylaColors.violet, width: 1.35),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NylaColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: NylaColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NylaColors.night,
        contentTextStyle: rounded(
          size: 13.5,
          weight: FontWeight.w600,
          color: Colors.white,
          height: 1.2,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      dividerColor: NylaColors.outline,
    );
  }
}
