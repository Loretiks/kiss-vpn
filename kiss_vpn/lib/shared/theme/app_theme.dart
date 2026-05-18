import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

class AppColors {
  static const accent = KissColors.pink;
  static const accentAlt = KissColors.violet;
  static const success = KissColors.success;
  static const warning = KissColors.warning;
  static const danger = KissColors.danger;

  static const bg0 = KissColors.bg0;
  static const bg1 = KissColors.bg1;
  static const bg2 = KissColors.bg2;
  static const bg3 = KissColors.bg3;

  static const textHi = KissColors.textHi;
  static const textMid = KissColors.textMid;
  static const textLow = KissColors.textLow;
}

class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: KissColors.pink,
      brightness: Brightness.dark,
      surface: KissColors.bg1,
      primary: KissColors.pink,
      secondary: KissColors.violet,
      error: KissColors.danger,
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: KissColors.bg0,
      canvasColor: KissColors.bg1,
      dividerColor: KissColors.stroke,
      brightness: Brightness.dark,
      splashFactory: InkSparkle.splashFactory,
    );

    final body = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: KissColors.textHi,
      displayColor: KissColors.textHi,
    );

    final display = GoogleFonts.unbounded;

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: display(
          textStyle: body.displayLarge,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        displayMedium: display(
          textStyle: body.displayMedium,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        displaySmall: display(
          textStyle: body.displaySmall,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        headlineLarge: display(
          textStyle: body.headlineLarge,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: display(
          textStyle: body.headlineMedium?.copyWith(fontSize: 28),
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineSmall: display(
          textStyle: body.headlineSmall,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: body.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: body.bodyMedium?.copyWith(height: 1.5),
        bodySmall: body.bodySmall?.copyWith(
          color: KissColors.textMid,
          height: 1.4,
        ),
        labelLarge: body.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: KissColors.bg2,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KissRadius.lg),
          side: const BorderSide(color: KissColors.stroke, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KissColors.pink,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: KissSpacing.xxl, vertical: KissSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KissRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KissColors.textHi,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w500),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: KissColors.textMid),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KissColors.bg2,
        labelStyle: GoogleFonts.manrope(color: KissColors.textMid),
        hintStyle: GoogleFonts.manrope(color: KissColors.textLow),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KissRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KissRadius.md),
          borderSide: const BorderSide(color: KissColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KissRadius.md),
          borderSide: const BorderSide(color: KissColors.pink, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: KissSpacing.lg, vertical: KissSpacing.md + 2),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: KissColors.bg1,
        indicatorColor: KissColors.pink.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: KissColors.pink, size: 22),
        unselectedIconTheme:
            const IconThemeData(color: KissColors.textMid, size: 22),
        selectedLabelTextStyle: GoogleFonts.manrope(
          color: KissColors.textHi,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: GoogleFonts.manrope(
          color: KissColors.textMid,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : KissColors.textLow,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? KissColors.pink
              : KissColors.bg3,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: KissColors.bg3,
        contentTextStyle: GoogleFonts.manrope(color: KissColors.textHi),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KissRadius.md),
          side: const BorderSide(color: KissColors.stroke),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: KissColors.pink,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: GoogleFonts.manropeTextTheme(),
    );
  }
}
