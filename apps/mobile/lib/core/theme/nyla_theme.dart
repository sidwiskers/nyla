import 'package:flutter/material.dart';

abstract final class NylaColors {
  static const canvas = Color(0xFFFCF8F4);
  static const paper = Color(0xFFFFFDFC);
  static const cream = Color(0xFFFFF9F5);
  static const surface = Color(0xFFFFFFFF);

  static const ink = Color(0xFF252033);
  static const mutedInk = Color(0xFF6E6875);
  static const faintInk = Color(0xFFA199A5);

  static const night = Color(0xFF30213F);
  static const wine = Color(0xFF64358A);
  static const violet = Color(0xFF8252A4);
  static const iris = Color(0xFF9E79B9);
  static const rose = Color(0xFFC85F81);
  static const coral = Color(0xFFE994A4);

  static const roseSoft = Color(0xFFF2C9D4);
  static const roseWash = Color(0xFFFBE9EE);
  static const peach = Color(0xFFEFC19F);
  static const peachSoft = Color(0xFFFBEADF);
  static const lavender = Color(0xFFD9C4E8);
  static const lavenderSoft = Color(0xFFF0E7F5);
  static const lavenderMist = Color(0xFFF8F4FA);
  static const sage = Color(0xFFC7D9B8);
  static const sageSoft = Color(0xFFEEF4E9);
  static const butter = Color(0xFFECDDAF);

  static const outline = Color(0xFFEAE2E5);
  static const outlineStrong = Color(0xFFDDD2D8);
  static const shadow = Color(0xFF30213F);
  static const warning = Color(0xFFA14E46);
}

abstract final class NylaTheme {
  static const _family = 'sans-serif';
  static const _fallback = <String>['Roboto', 'Arial', 'sans-serif'];

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
      fontFamily: _family,
      fontFamilyFallback: _fallback,
    );

    TextStyle text({
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.35,
      double spacing = 0,
    }) =>
        TextStyle(
          fontFamily: _family,
          fontFamilyFallback: _fallback,
          color: color,
          fontSize: size,
          height: height,
          fontWeight: weight,
          letterSpacing: spacing,
        );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: text(
          size: 36,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.04,
          spacing: -1.05,
        ),
        headlineMedium: text(
          size: 28,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.1,
          spacing: -0.55,
        ),
        titleLarge: text(
          size: 20,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.2,
          spacing: -0.2,
        ),
        titleMedium: text(
          size: 15.5,
          weight: FontWeight.w650,
          color: NylaColors.ink,
          height: 1.25,
        ),
        bodyLarge: text(
          size: 15,
          weight: FontWeight.w400,
          color: NylaColors.ink,
          height: 1.5,
        ),
        bodyMedium: text(
          size: 13.2,
          weight: FontWeight.w400,
          color: NylaColors.mutedInk,
          height: 1.45,
        ),
        labelLarge: text(
          size: 13.5,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.15,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: NylaColors.canvas,
        foregroundColor: NylaColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: text(
          size: 20,
          weight: FontWeight.w700,
          color: NylaColors.ink,
          height: 1.1,
          spacing: -0.2,
        ),
      ),
      cardTheme: const CardThemeData(
        color: NylaColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: NylaColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NylaColors.wine,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text(
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
          side: const BorderSide(color: NylaColors.outlineStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text(
            size: 13.5,
            weight: FontWeight.w700,
            color: NylaColors.wine,
            height: 1.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NylaColors.wine,
          textStyle: text(
            size: 13.5,
            weight: FontWeight.w700,
            color: NylaColors.wine,
            height: 1.1,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: NylaColors.paper,
        selectedColor: NylaColors.lavenderSoft,
        secondarySelectedColor: NylaColors.lavenderSoft,
        labelStyle: text(
          size: 11.5,
          weight: FontWeight.w600,
          color: NylaColors.mutedInk,
          height: 1.05,
        ),
        secondaryLabelStyle: text(
          size: 11.5,
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
        fillColor: NylaColors.paper,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: text(
          size: 13.5,
          weight: FontWeight.w400,
          color: NylaColors.faintInk,
          height: 1.2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NylaColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NylaColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NylaColors.violet, width: 1.3),
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
        thumbColor: NylaColors.wine,
        overlayColor: NylaColors.lavenderSoft,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NylaColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: NylaColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NylaColors.night,
        contentTextStyle: text(
          size: 13,
          weight: FontWeight.w600,
          color: Colors.white,
          height: 1.2,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: NylaColors.outline,
    );
  }
}
