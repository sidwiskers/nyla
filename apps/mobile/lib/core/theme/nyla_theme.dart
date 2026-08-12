import 'package:flutter/material.dart';

abstract final class NylaColors {
  static const canvas = Color(0xFFFBF8FC);
  static const cream = Color(0xFFFFFCFA);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B2231);
  static const mutedInk = Color(0xFF776D7D);
  static const faintInk = Color(0xFFA79DAA);

  static const night = Color(0xFF302438);
  static const wine = Color(0xFF5B405F);
  static const violet = Color(0xFF8269AE);
  static const iris = Color(0xFF9A83C0);
  static const rose = Color(0xFFC86F8E);
  static const coral = Color(0xFFE89A9A);

  static const roseSoft = Color(0xFFF5D4DE);
  static const roseWash = Color(0xFFFBECEF);
  static const peach = Color(0xFFF2C3A7);
  static const peachSoft = Color(0xFFFCEADF);
  static const lavender = Color(0xFFD9CBEA);
  static const lavenderSoft = Color(0xFFF0EAF8);
  static const lavenderMist = Color(0xFFF8F4FB);
  static const sage = Color(0xFFC6DCCF);
  static const sageSoft = Color(0xFFEDF5F0);
  static const butter = Color(0xFFF0DDA7);

  static const outline = Color(0xFFEDE5EF);
  static const outlineStrong = Color(0xFFE2D8E5);
  static const warning = Color(0xFF966455);
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

    TextStyle rounded({
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.3,
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
        displaySmall: rounded(
          size: 34,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.05,
          spacing: -0.72,
        ),
        headlineMedium: rounded(
          size: 27,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.1,
          spacing: -0.42,
        ),
        titleLarge: rounded(
          size: 20,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.18,
          spacing: -0.12,
        ),
        titleMedium: rounded(
          size: 15.5,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.24,
        ),
        bodyLarge: rounded(
          size: 15.5,
          weight: FontWeight.w400,
          color: NylaColors.ink,
          height: 1.5,
        ),
        bodyMedium: rounded(
          size: 13.5,
          weight: FontWeight.w400,
          color: NylaColors.mutedInk,
          height: 1.46,
        ),
        labelLarge: rounded(
          size: 13.5,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.15,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: NylaColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: rounded(
          size: 20,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.12,
        ),
      ),
      cardTheme: const CardThemeData(
        color: NylaColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NylaColors.violet,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: rounded(
            size: 13.5,
            weight: FontWeight.w700,
            color: Colors.white,
            height: 1.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NylaColors.wine,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          elevation: 0,
          side: const BorderSide(color: NylaColors.outlineStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: rounded(
            size: 13.5,
            weight: FontWeight.w700,
            color: NylaColors.wine,
            height: 1.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NylaColors.violet,
          textStyle: rounded(
            size: 13.5,
            weight: FontWeight.w700,
            color: NylaColors.violet,
            height: 1.1,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.86),
        selectedColor: NylaColors.lavenderSoft,
        secondarySelectedColor: NylaColors.lavenderSoft,
        labelStyle: rounded(
          size: 12,
          weight: FontWeight.w600,
          color: NylaColors.mutedInk,
          height: 1.05,
        ),
        secondaryLabelStyle: rounded(
          size: 12,
          weight: FontWeight.w700,
          color: NylaColors.wine,
          height: 1.05,
        ),
        side: const BorderSide(color: NylaColors.outline),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.88),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
        hintStyle: rounded(
          size: 13.5,
          weight: FontWeight.w400,
          color: NylaColors.faintInk,
          height: 1.2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: NylaColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: NylaColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: NylaColors.violet, width: 1.25),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NylaColors.lavender
              : NylaColors.outlineStrong,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: NylaColors.violet,
        inactiveTrackColor: NylaColors.lavenderSoft,
        thumbColor: NylaColors.violet,
        overlayColor: NylaColors.lavenderSoft,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NylaColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: NylaColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NylaColors.night,
        contentTextStyle: rounded(
          size: 13,
          weight: FontWeight.w600,
          color: Colors.white,
          height: 1.2,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: NylaColors.outline,
    );
  }
}
