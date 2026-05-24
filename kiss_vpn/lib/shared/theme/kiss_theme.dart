import 'package:flutter/material.dart';

import 'tokens.dart';

/// Context-dependent color palette attached to every ThemeData as a
/// [ThemeExtension]. Widgets read it via `KissTheme.of(context)` instead
/// of the static `KissColors` constants, so all surfaces, text and strokes
/// adapt to the active theme (Kiss / Dark / Light).
@immutable
class KissTheme extends ThemeExtension<KissTheme> {
  const KissTheme({
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.bg4,
    required this.accent,
    required this.accentDeep,
    required this.accentAlt,
    required this.accentAltDeep,
    required this.success,
    required this.successDeep,
    required this.warning,
    required this.danger,
    required this.info,
    required this.textHi,
    required this.textMid,
    required this.textLow,
    required this.textDim,
    required this.stroke,
    required this.strokeBright,
  });

  // Surfaces
  final Color bg0, bg1, bg2, bg3, bg4;

  // Primary accent (pink in Kiss, blue in Dark, pink in Light)
  final Color accent, accentDeep;
  // Secondary accent (violet in Kiss, same blue in Dark, violet in Light)
  final Color accentAlt, accentAltDeep;

  // Semantic
  final Color success, successDeep, warning, danger, info;

  // Text
  final Color textHi, textMid, textLow, textDim;

  // Borders
  final Color stroke, strokeBright;

  // ── convenience ──

  static KissTheme of(BuildContext context) =>
      Theme.of(context).extension<KissTheme>()!;

  // ── three presets ──

  static const kiss = KissTheme(
    bg0: KissColors.bg0,
    bg1: KissColors.bg1,
    bg2: KissColors.bg2,
    bg3: KissColors.bg3,
    bg4: KissColors.bg4,
    accent: KissColors.pink,
    accentDeep: KissColors.pinkDeep,
    accentAlt: KissColors.violet,
    accentAltDeep: KissColors.violetDeep,
    success: KissColors.success,
    successDeep: KissColors.successDeep,
    warning: KissColors.warning,
    danger: KissColors.danger,
    info: KissColors.info,
    textHi: KissColors.textHi,
    textMid: KissColors.textMid,
    textLow: KissColors.textLow,
    textDim: KissColors.textDim,
    stroke: KissColors.stroke,
    strokeBright: KissColors.strokeBright,
  );

  static const dark = KissTheme(
    bg0: Color(0xFF121212),
    bg1: Color(0xFF1E1E1E),
    bg2: Color(0xFF252525),
    bg3: Color(0xFF2E2E2E),
    bg4: Color(0xFF383838),
    accent: Color(0xFF8AB4F8),
    accentDeep: Color(0xFF5A8AD8),
    accentAlt: Color(0xFF8AB4F8),
    accentAltDeep: Color(0xFF5A8AD8),
    success: KissColors.success,
    successDeep: KissColors.successDeep,
    warning: KissColors.warning,
    danger: KissColors.danger,
    info: KissColors.info,
    textHi: Color(0xFFE8E8E8),
    textMid: Color(0xFFA0A0A0),
    textLow: Color(0xFF707070),
    textDim: Color(0xFF505050),
    stroke: Color(0xFF333333),
    strokeBright: Color(0xFF484848),
  );

  static const light = KissTheme(
    bg0: Color(0xFFF2F2F6),
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFEDEDF3),
    bg3: Color(0xFFE0E0EA),
    bg4: Color(0xFFD2D2E0),
    accent: KissColors.pink,
    accentDeep: KissColors.pinkDeep,
    accentAlt: KissColors.violet,
    accentAltDeep: KissColors.violetDeep,
    success: Color(0xFF1A9960),
    successDeep: KissColors.successDeep,
    warning: Color(0xFFCC8800),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
    textHi: Color(0xFF1A1A2E),
    textMid: Color(0xFF4A4A68),
    textLow: Color(0xFF6E6E8A),
    textDim: Color(0xFF9898B0),
    stroke: Color(0xFFD8D8E5),
    strokeBright: Color(0xFFC0C0D2),
  );

  // ── ThemeExtension plumbing ──

  @override
  KissTheme copyWith({
    Color? bg0, Color? bg1, Color? bg2, Color? bg3, Color? bg4,
    Color? accent, Color? accentDeep, Color? accentAlt, Color? accentAltDeep,
    Color? success, Color? successDeep, Color? warning, Color? danger, Color? info,
    Color? textHi, Color? textMid, Color? textLow, Color? textDim,
    Color? stroke, Color? strokeBright,
  }) => KissTheme(
    bg0: bg0 ?? this.bg0,
    bg1: bg1 ?? this.bg1,
    bg2: bg2 ?? this.bg2,
    bg3: bg3 ?? this.bg3,
    bg4: bg4 ?? this.bg4,
    accent: accent ?? this.accent,
    accentDeep: accentDeep ?? this.accentDeep,
    accentAlt: accentAlt ?? this.accentAlt,
    accentAltDeep: accentAltDeep ?? this.accentAltDeep,
    success: success ?? this.success,
    successDeep: successDeep ?? this.successDeep,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    textHi: textHi ?? this.textHi,
    textMid: textMid ?? this.textMid,
    textLow: textLow ?? this.textLow,
    textDim: textDim ?? this.textDim,
    stroke: stroke ?? this.stroke,
    strokeBright: strokeBright ?? this.strokeBright,
  );

  @override
  KissTheme lerp(KissTheme? other, double t) {
    if (other == null) return this;
    return KissTheme(
      bg0: Color.lerp(bg0, other.bg0, t)!,
      bg1: Color.lerp(bg1, other.bg1, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      bg3: Color.lerp(bg3, other.bg3, t)!,
      bg4: Color.lerp(bg4, other.bg4, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentAlt: Color.lerp(accentAlt, other.accentAlt, t)!,
      accentAltDeep: Color.lerp(accentAltDeep, other.accentAltDeep, t)!,
      success: Color.lerp(success, other.success, t)!,
      successDeep: Color.lerp(successDeep, other.successDeep, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      textHi: Color.lerp(textHi, other.textHi, t)!,
      textMid: Color.lerp(textMid, other.textMid, t)!,
      textLow: Color.lerp(textLow, other.textLow, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      strokeBright: Color.lerp(strokeBright, other.strokeBright, t)!,
    );
  }
}
