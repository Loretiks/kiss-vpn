import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kiss_theme.dart';
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
  // ── Kiss: branded pink-violet on near-black (the original design) ──

  static ThemeData kiss() {
    return _buildDark(ext: KissTheme.kiss,
      seedColor: KissColors.pink,
      primary: KissColors.pink,
      secondary: KissColors.violet,
      scaffoldBg: KissColors.bg0,
      canvasBg: KissColors.bg1,
      cardBg: KissColors.bg2,
      surfaceBg: KissColors.bg1,
      divider: KissColors.stroke,
      textHi: KissColors.textHi,
      textMid: KissColors.textMid,
      textLow: KissColors.textLow,
      inputFill: KissColors.bg2,
      switchTrack: KissColors.bg3,
      snackBg: KissColors.bg3,
      accentGlow: KissColors.pink,
    );
  }

  // ── Dark: neutral gray, no brand accent ──

  static ThemeData dark() {
    const primary = Color(0xFF8AB4F8);
    const secondary = Color(0xFF8AB4F8);
    const scaffoldBg = Color(0xFF121212);
    const canvasBg = Color(0xFF1E1E1E);
    const cardBg = Color(0xFF252525);
    const divider = Color(0xFF333333);
    const textHi = Color(0xFFE8E8E8);
    const textMid = Color(0xFFA0A0A0);
    const textLow = Color(0xFF707070);

    return _buildDark(ext: KissTheme.dark,
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      scaffoldBg: scaffoldBg,
      canvasBg: canvasBg,
      cardBg: cardBg,
      surfaceBg: canvasBg,
      divider: divider,
      textHi: textHi,
      textMid: textMid,
      textLow: textLow,
      inputFill: cardBg,
      switchTrack: const Color(0xFF3A3A3A),
      snackBg: cardBg,
      accentGlow: primary,
    );
  }

  // ── Light ──

  static ThemeData light() {
    const primary = KissColors.pink;
    const secondary = KissColors.violet;
    const surfaceBg = Color(0xFFF4F4F8);
    const cardBg = Color(0xFFFFFFFF);
    const strokeLight = Color(0xFFE0E0EA);
    const textHi = Color(0xFF1A1A2E);
    const textMid = Color(0xFF5A5A7A);
    const textLow = Color(0xFF9090AA);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      error: KissColors.danger,
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceBg,
      canvasColor: cardBg,
      dividerColor: strokeLight,
      brightness: Brightness.light,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      extensions: [KissTheme.light],
      textTheme: _textTheme(base, textHi, textMid),
      cardTheme: _card(cardBg, strokeLight),
      filledButtonTheme: _filledButton(primary),
      textButtonTheme: _textButton(textHi),
      iconButtonTheme: _iconButton(textMid),
      inputDecorationTheme: _input(cardBg, strokeLight, textMid, textLow, primary),
      navigationRailTheme: _navRail(cardBg, primary, textHi, textMid),
      switchTheme: _switch(primary, textLow, const Color(0xFFD0D0DD)),
      snackBarTheme: _snack(cardBg, textHi, strokeLight),
    );
  }

  // ── shared builder for dark variants ──

  static ThemeData _buildDark({
    required KissTheme ext,
    required Color seedColor,
    required Color primary,
    required Color secondary,
    required Color scaffoldBg,
    required Color canvasBg,
    required Color cardBg,
    required Color surfaceBg,
    required Color divider,
    required Color textHi,
    required Color textMid,
    required Color textLow,
    required Color inputFill,
    required Color switchTrack,
    required Color snackBg,
    required Color accentGlow,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: surfaceBg,
      primary: primary,
      secondary: secondary,
      error: KissColors.danger,
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: canvasBg,
      dividerColor: divider,
      brightness: Brightness.dark,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      extensions: [ext],
      textTheme: _textTheme(base, textHi, textMid),
      cardTheme: _card(cardBg, divider),
      filledButtonTheme: _filledButton(primary),
      textButtonTheme: _textButton(textHi),
      iconButtonTheme: _iconButton(textMid),
      inputDecorationTheme: _input(inputFill, divider, textMid, textLow, primary),
      navigationRailTheme: _navRail(canvasBg, primary, textHi, textMid),
      switchTheme: _switch(primary, textLow, switchTrack),
      snackBarTheme: _snack(snackBg, textHi, divider),
    );
  }

  // ── component helpers ──

  static TextTheme _textTheme(ThemeData base, Color hi, Color mid) {
    final body = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: hi,
      displayColor: hi,
    );
    final display = GoogleFonts.unbounded;
    return body.copyWith(
      displayLarge: display(textStyle: body.displayLarge, fontWeight: FontWeight.w700, letterSpacing: -1.2),
      displayMedium: display(textStyle: body.displayMedium, fontWeight: FontWeight.w700, letterSpacing: -0.8),
      displaySmall: display(textStyle: body.displaySmall, fontWeight: FontWeight.w600, letterSpacing: -0.4),
      headlineLarge: display(textStyle: body.headlineLarge, fontWeight: FontWeight.w700, letterSpacing: -0.8),
      headlineMedium: display(textStyle: body.headlineMedium?.copyWith(fontSize: 28), fontWeight: FontWeight.w700, letterSpacing: -0.6),
      headlineSmall: display(textStyle: body.headlineSmall, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.5),
      bodySmall: body.bodySmall?.copyWith(color: mid, height: 1.4),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
    );
  }

  static CardThemeData _card(Color bg, Color border) => CardThemeData(
        color: bg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KissRadius.lg),
          side: BorderSide(color: border, width: 1),
        ),
      );

  static FilledButtonThemeData _filledButton(Color bg) => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, letterSpacing: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: KissSpacing.xxl, vertical: KissSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KissRadius.md)),
        ),
      );

  static TextButtonThemeData _textButton(Color fg) => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w500),
        ),
      );

  static IconButtonThemeData _iconButton(Color fg) => IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: fg),
      );

  static InputDecorationTheme _input(Color fill, Color border, Color label, Color hint, Color focus) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        labelStyle: GoogleFonts.manrope(color: label),
        hintStyle: GoogleFonts.manrope(color: hint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(KissRadius.md), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(KissRadius.md), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(KissRadius.md), borderSide: BorderSide(color: focus, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: KissSpacing.lg, vertical: KissSpacing.md + 2),
      );

  static NavigationRailThemeData _navRail(Color bg, Color accent, Color hi, Color mid) =>
      NavigationRailThemeData(
        backgroundColor: bg,
        indicatorColor: accent.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: accent, size: 22),
        unselectedIconTheme: IconThemeData(color: mid, size: 22),
        selectedLabelTextStyle: GoogleFonts.manrope(color: hi, fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelTextStyle: GoogleFonts.manrope(color: mid, fontWeight: FontWeight.w500, fontSize: 13),
      );

  static SwitchThemeData _switch(Color accent, Color thumbOff, Color trackOff) => SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : thumbOff,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : trackOff,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      );

  static SnackBarThemeData _snack(Color bg, Color text, Color border) => SnackBarThemeData(
        backgroundColor: bg,
        contentTextStyle: GoogleFonts.manrope(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KissRadius.md),
          side: BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      );
}
