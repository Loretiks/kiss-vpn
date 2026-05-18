import 'package:flutter/material.dart';

/// Design tokens for Kiss VPN. Pink-violet brand on near-black surfaces.
class KissColors {
  // Surface ladder.
  static const bg0 = Color(0xFF06060B);
  static const bg1 = Color(0xFF0C0C14);
  static const bg2 = Color(0xFF14141F);
  static const bg3 = Color(0xFF1C1C2A);
  static const bg4 = Color(0xFF252535);

  // Brand pair.
  static const pink = Color(0xFFFF3B7A);
  static const pinkDeep = Color(0xFFE21F62);
  static const violet = Color(0xFF7C5CFF);
  static const violetDeep = Color(0xFF5635E0);

  // Semantic.
  static const success = Color(0xFF34D399);
  static const successDeep = Color(0xFF0E7C5A);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF60A5FA);

  // Text ladder.
  static const textHi = Color(0xFFF8F8FC);
  static const textMid = Color(0xFFB8B8C8);
  static const textLow = Color(0xFF7878A0);
  static const textDim = Color(0xFF4F4F6E);

  // Borders / strokes.
  static const stroke = Color(0xFF26263A);
  static const strokeBright = Color(0xFF3A3A55);
}

class KissGradients {
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [KissColors.pink, KissColors.violet],
  );

  static const brandSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB52559), Color(0xFF4F37C2)],
  );

  static const surface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1B1B27), Color(0xFF131320)],
  );

  static List<Color> meshPinkViolet = const [
    Color(0x66FF3B7A),
    Color(0x447C5CFF),
    Color(0x00000000),
  ];

  static const ringIdle = brand;
  static const ringConnecting = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFFF3B7A)],
  );
  static const ringConnected = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF34D399)],
  );
  static const ringError = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFFF3B7A)],
  );
}

class KissSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const x3 = 32.0;
  static const x4 = 40.0;
  static const x5 = 48.0;
  static const x6 = 64.0;
  static const x7 = 80.0;
}

class KissRadius {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

class KissShadows {
  static const card = [
    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const glowPink = [
    BoxShadow(color: Color(0x55FF3B7A), blurRadius: 32, spreadRadius: 2),
  ];
  static const glowViolet = [
    BoxShadow(color: Color(0x447C5CFF), blurRadius: 32, spreadRadius: 2),
  ];
  static const glowSuccess = [
    BoxShadow(color: Color(0x6634D399), blurRadius: 36, spreadRadius: 2),
  ];
}

class KissDurations {
  static const fast = Duration(milliseconds: 150);
  static const med = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 400);
  static const pulse = Duration(milliseconds: 1800);
  static const ring = Duration(seconds: 4);
}

const kFontFallback = <String>[
  'Segoe UI Emoji',
  'Segoe UI Symbol',
  'Segoe UI',
  'Noto Color Emoji',
];
