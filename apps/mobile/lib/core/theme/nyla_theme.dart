import 'package:flutter/material.dart';

abstract final class NylaColors {
  static const canvas = Color(0xFFFBF7F3);
  static const paper = Color(0xFFFFFDF9);
  static const cream = Color(0xFFFFFAF6);
  static const surface = Color(0xFFFFFFFF);

  static const ink = Color(0xFF24161D);
  static const mutedInk = Color(0xFF716269);
  static const faintInk = Color(0xFFA99AA0);

  static const night = Color(0xFF28101D);
  static const wine = Color(0xFF381426);
  static const violet = Color(0xFF6F4C5F);
  static const iris = Color(0xFF977286);
  static const rose = Color(0xFFB76570);
  static const coral = Color(0xFFDF8F86);

  static const roseSoft = Color(0xFFF1D0D5);
  static const roseWash = Color(0xFFF8E9EB);
  static const peach = Color(0xFFECC2A5);
  static const peachSoft = Color(0xFFF9E9DC);
  static const lavender = Color(0xFFD9D0E2);
  static const lavenderSoft = Color(0xFFF0EBF4);
  static const lavenderMist = Color(0xFFF7F3F7);
  static const sage = Color(0xFFBBD3C6);
  static const sageSoft = Color(0xFFE8F1EC);
  static const butter = Color(0xFFEBD8A2);

  static const outline = Color(0xFFE8DEDA);
  static const outlineStrong = Color(0xFFD9CBC8);
  static const shadow = Color(0xFF2A111E);
  static const warning = Color(0xFF8D4B3C);
}

abstract final class NylaTheme {
  static const _display = 'sans-serif';
  static const _rounded = 'sans-serif-rounded';
  static const _fallback = <String>['Roboto', 'sans-serif'];

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: NylaColors.wine,
      brightness: Brightness.light,
      surface: NylaColors.canvas,
    ).copyWith(
      primary: NylaColors.wine,
      onPrimary: Colors.white,
      secondary: NylaColors.rose,
      onSecondary: Colors.white,
      tertiary: NylaColors.sage,
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
      fontFamily: _rounded,
      fontFamilyFallback: _fallback,
    );

    TextStyle display({
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.12,
      double spacing = 0,
    }) =>
        TextStyle(
          fontFamily: _display,
          fontFamilyFallback: _fallback,
          color: color,
          fontSize: size,
          height: height,
          fontWeight: weight,
          letterSpacing: spacing,
        );

    TextStyle body({
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.45,
      double spacing = 0,
    }) =>
        TextStyle(
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
        displaySmall: display(
          size: 38,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.02,
          spacing: -1.15,
        ),
        headlineMedium: display(
          size: 29,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.08,
          spacing: -0.72,
        ),
        titleLarge: display(
          size: 20,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.16,
          spacing: -0.25,
        ),
        titleMedium: body(
          size: 16,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.2,
          spacing: -0.04,
        ),
        bodyLarge: body(
          size: 16,
          weight: FontWeight.w400,
          color: NylaColors.ink,
          height: 1.52,
          spacing: -0.02,
        ),
        bodyMedium: body(
          size: 14,
          weight: FontWeight.w400,
          color: NylaColors.mutedInk,
          height: 1.48,
        ),
        labelLarge: body(
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
        titleTextStyle: display(
          size: 21,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.08,
          spacing: -0.22,
        ),
      ),
      cardTheme: const CardThemeData(
        color: NylaColors.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NylaColors.wine,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: body(
            size: 14,
            weight: FontWeight.w700,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NylaColors.wine,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: NylaColors.outlineStrong),
          shape: const StadiumBorder(),
          textStyle: body(
            size: 14,
            weight: FontWeight.w700,
            color: NylaColors.wine,
            height: 1.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NylaColors.wine,
          textStyle: body(
            size: 14,
            weight: FontWeight.w700,
            color: NylaColors.wine,
            height: 1.1,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: NylaColors.paper,
        selectedColor: NylaColors.wine,
        secondarySelectedColor: NylaColors.wine,
        labelStyle: body(
          size: 12.5,
          weight: FontWeight.w600,
          color: NylaColors.ink,
          height: 1.05,
        ),
        secondaryLabelStyle: body(
          size: 12.5,
          weight: FontWeight.w700,
          color: Colors.white,
          height: 1.05,
        ),
        side: const BorderSide(color: NylaColors.outline),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1EDE9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: body(
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
          borderSide: const BorderSide(color: Color(0x00FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: NylaColors.rose, width: 1.4),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NylaColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: NylaColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NylaColors.night,
        contentTextStyle: body(
          size: 13.5,
          weight: FontWeight.w600,
          color: Colors.white,
          height: 1.2,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerColor: NylaColors.outline,
    );
  }
}
