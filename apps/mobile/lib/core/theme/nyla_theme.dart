import 'package:flutter/material.dart';

abstract final class NylaColors {
  static const canvas = Color(0xFFFFF7F3);
  static const cream = Color(0xFFFFFCF8);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2C2028);
  static const mutedInk = Color(0xFF76666E);
  static const faintInk = Color(0xFFA6959E);

  static const wine = Color(0xFF542B3C);
  static const rose = Color(0xFFAD4868);
  static const coral = Color(0xFFE6807A);
  static const roseSoft = Color(0xFFF7CED8);
  static const roseWash = Color(0xFFFCE9EC);
  static const peach = Color(0xFFF5C7A9);
  static const peachSoft = Color(0xFFFBE7D9);
  static const lavender = Color(0xFFD9C8EA);
  static const lavenderSoft = Color(0xFFF0E9F7);
  static const sage = Color(0xFFBDD3C2);
  static const sageSoft = Color(0xFFE5F0E7);
  static const butter = Color(0xFFF3D58F);

  static const outline = Color(0xFFEEDFE3);
  static const warning = Color(0xFF8C5038);
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
      secondary: NylaColors.wine,
      onSecondary: Colors.white,
      surface: NylaColors.canvas,
      onSurface: NylaColors.ink,
      outline: NylaColors.outline,
      surfaceContainerHighest: NylaColors.roseWash,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: NylaColors.canvas,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          color: NylaColors.ink,
          fontSize: 38,
          height: 1.02,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.35,
        ),
        headlineMedium: const TextStyle(
          color: NylaColors.ink,
          fontSize: 29,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
        ),
        titleLarge: const TextStyle(
          color: NylaColors.ink,
          fontSize: 20,
          height: 1.16,
          fontWeight: FontWeight.w750,
          letterSpacing: -0.35,
        ),
        titleMedium: const TextStyle(
          color: NylaColors.ink,
          fontSize: 16,
          height: 1.22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
        ),
        bodyLarge: const TextStyle(
          color: NylaColors.ink,
          fontSize: 16,
          height: 1.5,
          letterSpacing: -0.08,
        ),
        bodyMedium: const TextStyle(
          color: NylaColors.mutedInk,
          fontSize: 14,
          height: 1.48,
          letterSpacing: -0.03,
        ),
        labelLarge: const TextStyle(
          color: NylaColors.ink,
          fontSize: 14,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.05,
        ),
      ),
      cardTheme: const CardThemeData(
        color: NylaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NylaColors.wine,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NylaColors.rose,
          textStyle: const TextStyle(fontWeight: FontWeight.w750),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.68),
        selectedColor: NylaColors.wine,
        secondarySelectedColor: NylaColors.wine,
        labelStyle: const TextStyle(color: NylaColors.ink, fontWeight: FontWeight.w650),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w750),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.86),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: NylaColors.faintInk),
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
          borderSide: const BorderSide(color: NylaColors.rose, width: 1.4),
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NylaColors.wine,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w650),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: NylaColors.outline,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
