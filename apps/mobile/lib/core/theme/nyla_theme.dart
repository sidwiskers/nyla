import 'package:flutter/material.dart';

/// Stable brand colours used by artwork and deliberately-dark feature panels.
///
/// Screens should use [BuildContext.nyla] for semantic surfaces, text and tints
/// so they participate in light/dark interpolation.
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

@immutable
class NylaPalette extends ThemeExtension<NylaPalette> {
  const NylaPalette({
    required this.canvas,
    required this.cream,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.mutedInk,
    required this.faintInk,
    required this.wine,
    required this.violet,
    required this.iris,
    required this.rose,
    required this.coral,
    required this.roseSoft,
    required this.roseWash,
    required this.peach,
    required this.peachSoft,
    required this.lavender,
    required this.lavenderSoft,
    required this.lavenderMist,
    required this.sage,
    required this.sageSoft,
    required this.butter,
    required this.outline,
    required this.outlineStrong,
    required this.warning,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.navSurface,
    required this.shadow,
    required this.pageTop,
    required this.pageBottom,
    required this.orbViolet,
    required this.orbRose,
    required this.expected,
    required this.expectedFill,
    required this.expectedInk,
    required this.systemBar,
  });

  static const light = NylaPalette(
    canvas: Color(0xFFFBF8FC),
    cream: Color(0xFFFFFCFA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFDFE),
    ink: Color(0xFF2B2231),
    mutedInk: Color(0xFF776D7D),
    faintInk: Color(0xFFA79DAA),
    wine: Color(0xFF5B405F),
    violet: Color(0xFF8269AE),
    iris: Color(0xFF9A83C0),
    rose: Color(0xFFC86F8E),
    coral: Color(0xFFE89A9A),
    roseSoft: Color(0xFFF5D4DE),
    roseWash: Color(0xFFFBECEF),
    peach: Color(0xFFF2C3A7),
    peachSoft: Color(0xFFFCEADF),
    lavender: Color(0xFFD9CBEA),
    lavenderSoft: Color(0xFFF0EAF8),
    lavenderMist: Color(0xFFF8F4FB),
    sage: Color(0xFFC6DCCF),
    sageSoft: Color(0xFFEDF5F0),
    butter: Color(0xFFF0DDA7),
    outline: Color(0xFFEDE5EF),
    outlineStrong: Color(0xFFE2D8E5),
    warning: Color(0xFF966455),
    glass: Color(0xCFFFFFFF),
    glassStrong: Color(0xEBFFFFFF),
    glassBorder: Color(0xE6FFFFFF),
    navSurface: Color(0xF5FFFCFE),
    shadow: Color(0x172B2231),
    pageTop: Color(0xFFF0E8F8),
    pageBottom: Color(0xFFFFF4EE),
    orbViolet: Color(0x1A8B6FC0),
    orbRose: Color(0x12E27E83),
    expected: Color(0xFF6F9B82),
    expectedFill: Color(0xFFE8F2EC),
    expectedInk: Color(0xFF4D715D),
    systemBar: Color(0xFFF8F3F8),
  );

  static const dark = NylaPalette(
    canvas: Color(0xFF151219),
    cream: Color(0xFF1B171F),
    surface: Color(0xFF211B26),
    surfaceRaised: Color(0xFF28202E),
    ink: Color(0xFFF6EFF8),
    mutedInk: Color(0xFFC7BBCB),
    faintInk: Color(0xFF958A9A),
    wine: Color(0xFFD9BEDB),
    violet: Color(0xFFB8A0E1),
    iris: Color(0xFFAA94D0),
    rose: Color(0xFFE99AB6),
    coral: Color(0xFFF0AAA7),
    roseSoft: Color(0xFF492E3A),
    roseWash: Color(0xFF34232D),
    peach: Color(0xFF5A4033),
    peachSoft: Color(0xFF3A2A25),
    lavender: Color(0xFF4C3E61),
    lavenderSoft: Color(0xFF30283C),
    lavenderMist: Color(0xFF241F2B),
    sage: Color(0xFF3E5A4B),
    sageSoft: Color(0xFF25342D),
    butter: Color(0xFF5B5030),
    outline: Color(0xFF342D3A),
    outlineStrong: Color(0xFF453A4B),
    warning: Color(0xFFE0A28F),
    glass: Color(0xB8241E2A),
    glassStrong: Color(0xED29222F),
    glassBorder: Color(0x704A3E50),
    navSurface: Color(0xF51D1822),
    shadow: Color(0x73000000),
    pageTop: Color(0xFF1E1826),
    pageBottom: Color(0xFF1B161B),
    orbViolet: Color(0x269C7BD1),
    orbRose: Color(0x1FC56F91),
    expected: Color(0xFF8FC5A6),
    expectedFill: Color(0xFF24382E),
    expectedInk: Color(0xFFB8DEC8),
    systemBar: Color(0xFF151219),
  );

  final Color canvas;
  final Color cream;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color mutedInk;
  final Color faintInk;
  final Color wine;
  final Color violet;
  final Color iris;
  final Color rose;
  final Color coral;
  final Color roseSoft;
  final Color roseWash;
  final Color peach;
  final Color peachSoft;
  final Color lavender;
  final Color lavenderSoft;
  final Color lavenderMist;
  final Color sage;
  final Color sageSoft;
  final Color butter;
  final Color outline;
  final Color outlineStrong;
  final Color warning;
  final Color glass;
  final Color glassStrong;
  final Color glassBorder;
  final Color navSurface;
  final Color shadow;
  final Color pageTop;
  final Color pageBottom;
  final Color orbViolet;
  final Color orbRose;
  final Color expected;
  final Color expectedFill;
  final Color expectedInk;
  final Color systemBar;

  @override
  NylaPalette copyWith({
    Color? canvas,
    Color? cream,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? mutedInk,
    Color? faintInk,
    Color? wine,
    Color? violet,
    Color? iris,
    Color? rose,
    Color? coral,
    Color? roseSoft,
    Color? roseWash,
    Color? peach,
    Color? peachSoft,
    Color? lavender,
    Color? lavenderSoft,
    Color? lavenderMist,
    Color? sage,
    Color? sageSoft,
    Color? butter,
    Color? outline,
    Color? outlineStrong,
    Color? warning,
    Color? glass,
    Color? glassStrong,
    Color? glassBorder,
    Color? navSurface,
    Color? shadow,
    Color? pageTop,
    Color? pageBottom,
    Color? orbViolet,
    Color? orbRose,
    Color? expected,
    Color? expectedFill,
    Color? expectedInk,
    Color? systemBar,
  }) =>
      NylaPalette(
        canvas: canvas ?? this.canvas,
        cream: cream ?? this.cream,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        ink: ink ?? this.ink,
        mutedInk: mutedInk ?? this.mutedInk,
        faintInk: faintInk ?? this.faintInk,
        wine: wine ?? this.wine,
        violet: violet ?? this.violet,
        iris: iris ?? this.iris,
        rose: rose ?? this.rose,
        coral: coral ?? this.coral,
        roseSoft: roseSoft ?? this.roseSoft,
        roseWash: roseWash ?? this.roseWash,
        peach: peach ?? this.peach,
        peachSoft: peachSoft ?? this.peachSoft,
        lavender: lavender ?? this.lavender,
        lavenderSoft: lavenderSoft ?? this.lavenderSoft,
        lavenderMist: lavenderMist ?? this.lavenderMist,
        sage: sage ?? this.sage,
        sageSoft: sageSoft ?? this.sageSoft,
        butter: butter ?? this.butter,
        outline: outline ?? this.outline,
        outlineStrong: outlineStrong ?? this.outlineStrong,
        warning: warning ?? this.warning,
        glass: glass ?? this.glass,
        glassStrong: glassStrong ?? this.glassStrong,
        glassBorder: glassBorder ?? this.glassBorder,
        navSurface: navSurface ?? this.navSurface,
        shadow: shadow ?? this.shadow,
        pageTop: pageTop ?? this.pageTop,
        pageBottom: pageBottom ?? this.pageBottom,
        orbViolet: orbViolet ?? this.orbViolet,
        orbRose: orbRose ?? this.orbRose,
        expected: expected ?? this.expected,
        expectedFill: expectedFill ?? this.expectedFill,
        expectedInk: expectedInk ?? this.expectedInk,
        systemBar: systemBar ?? this.systemBar,
      );

  @override
  NylaPalette lerp(covariant NylaPalette? other, double t) {
    if (other == null) return this;
    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;
    return NylaPalette(
      canvas: blend(canvas, other.canvas),
      cream: blend(cream, other.cream),
      surface: blend(surface, other.surface),
      surfaceRaised: blend(surfaceRaised, other.surfaceRaised),
      ink: blend(ink, other.ink),
      mutedInk: blend(mutedInk, other.mutedInk),
      faintInk: blend(faintInk, other.faintInk),
      wine: blend(wine, other.wine),
      violet: blend(violet, other.violet),
      iris: blend(iris, other.iris),
      rose: blend(rose, other.rose),
      coral: blend(coral, other.coral),
      roseSoft: blend(roseSoft, other.roseSoft),
      roseWash: blend(roseWash, other.roseWash),
      peach: blend(peach, other.peach),
      peachSoft: blend(peachSoft, other.peachSoft),
      lavender: blend(lavender, other.lavender),
      lavenderSoft: blend(lavenderSoft, other.lavenderSoft),
      lavenderMist: blend(lavenderMist, other.lavenderMist),
      sage: blend(sage, other.sage),
      sageSoft: blend(sageSoft, other.sageSoft),
      butter: blend(butter, other.butter),
      outline: blend(outline, other.outline),
      outlineStrong: blend(outlineStrong, other.outlineStrong),
      warning: blend(warning, other.warning),
      glass: blend(glass, other.glass),
      glassStrong: blend(glassStrong, other.glassStrong),
      glassBorder: blend(glassBorder, other.glassBorder),
      navSurface: blend(navSurface, other.navSurface),
      shadow: blend(shadow, other.shadow),
      pageTop: blend(pageTop, other.pageTop),
      pageBottom: blend(pageBottom, other.pageBottom),
      orbViolet: blend(orbViolet, other.orbViolet),
      orbRose: blend(orbRose, other.orbRose),
      expected: blend(expected, other.expected),
      expectedFill: blend(expectedFill, other.expectedFill),
      expectedInk: blend(expectedInk, other.expectedInk),
      systemBar: blend(systemBar, other.systemBar),
    );
  }
}

extension NylaThemeContext on BuildContext {
  NylaPalette get nyla => Theme.of(this).extension<NylaPalette>()!;
}

abstract final class NylaTheme {
  static const _rounded = 'sans-serif-rounded';
  static const _fallback = <String>['sans-serif', 'Roboto'];

  static ThemeData get light => _build(Brightness.light, NylaPalette.light);
  static ThemeData get dark => _build(Brightness.dark, NylaPalette.dark);

  static ThemeData _build(Brightness brightness, NylaPalette palette) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: dark ? palette.violet : NylaColors.violet,
      brightness: brightness,
      surface: palette.canvas,
    ).copyWith(
      primary: palette.violet,
      onPrimary: dark ? const Color(0xFF1D1428) : Colors.white,
      secondary: palette.rose,
      onSecondary: dark ? const Color(0xFF2B1520) : Colors.white,
      tertiary: palette.sage,
      surface: palette.canvas,
      onSurface: palette.ink,
      outline: palette.outline,
      surfaceContainerHighest: palette.lavenderSoft,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      splashFactory: InkRipple.splashFactory,
      fontFamily: _rounded,
      fontFamilyFallback: _fallback,
      extensions: [palette],
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
        displaySmall: rounded(size: 34, weight: FontWeight.w700, color: palette.ink, height: 1.05, spacing: -0.72),
        headlineMedium: rounded(size: 27, weight: FontWeight.w700, color: palette.ink, height: 1.1, spacing: -0.42),
        titleLarge: rounded(size: 20, weight: FontWeight.w700, color: palette.ink, height: 1.18, spacing: -0.12),
        titleMedium: rounded(size: 15.5, weight: FontWeight.w700, color: palette.ink, height: 1.24),
        bodyLarge: rounded(size: 15.5, weight: FontWeight.w400, color: palette.ink, height: 1.5),
        bodyMedium: rounded(size: 13.5, weight: FontWeight.w400, color: palette.mutedInk, height: 1.46),
        labelLarge: rounded(size: 13.5, weight: FontWeight.w700, color: palette.ink, height: 1.15),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: rounded(size: 20, weight: FontWeight.w700, color: palette.ink, height: 1.12),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.outline.withValues(alpha: dark ? 0.7 : 0)),
          borderRadius: const BorderRadius.all(Radius.circular(26)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.mutedInk,
        textColor: palette.ink,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.violet,
        foregroundColor: dark ? const Color(0xFF1D1428) : Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.violet,
          foregroundColor: dark ? const Color(0xFF1D1428) : Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: rounded(size: 13.5, weight: FontWeight.w700, color: dark ? const Color(0xFF1D1428) : Colors.white, height: 1.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.wine,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          elevation: 0,
          side: BorderSide(color: palette.outlineStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: rounded(size: 13.5, weight: FontWeight.w700, color: palette.wine, height: 1.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.violet,
          textStyle: rounded(size: 13.5, weight: FontWeight.w700, color: palette.violet, height: 1.1),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.glassStrong,
        selectedColor: palette.lavenderSoft,
        secondarySelectedColor: palette.lavenderSoft,
        labelStyle: rounded(size: 12, weight: FontWeight.w600, color: palette.mutedInk, height: 1.05),
        secondaryLabelStyle: rounded(size: 12, weight: FontWeight.w700, color: palette.wine, height: 1.05),
        side: BorderSide(color: palette.outline),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.glassStrong,
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
        hintStyle: rounded(size: 13.5, weight: FontWeight.w400, color: palette.faintInk, height: 1.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.violet, width: 1.25),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? palette.lavender : palette.outlineStrong,
        ),
        thumbColor: WidgetStatePropertyAll(dark ? palette.ink : Colors.white),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: palette.violet,
        inactiveTrackColor: palette.lavenderSoft,
        thumbColor: palette.violet,
        overlayColor: palette.lavenderSoft,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.cream,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: dark ? 0.62 : 0.35),
        dragHandleColor: palette.faintInk,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.cream,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: palette.cream,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: palette.lavenderSoft,
        headerForegroundColor: palette.ink,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: palette.cream,
        hourMinuteColor: palette.lavenderSoft,
        hourMinuteTextColor: palette.ink,
        dialBackgroundColor: palette.surface,
        dialHandColor: palette.violet,
        dialTextColor: palette.ink,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? palette.surfaceRaised : NylaColors.night,
        contentTextStyle: rounded(size: 13, weight: FontWeight.w600, color: dark ? palette.ink : Colors.white, height: 1.2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: palette.outline,
    );
  }
}
