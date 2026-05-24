import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../theme/kiss_theme.dart';
import '../theme/tokens.dart';
import '../utils/country.dart';

/// Renders the country flag for a [Country] in a square tile.
///
/// Uses the `country_flags` package (SVG) because Flutter on Windows
/// doesn't cluster the two regional-indicator code points into a single
/// flag emoji glyph — fallback fonts like Segoe UI Emoji render them as
/// the underlying letters (`FI`, `PL`, …) instead.
class FlagBadge extends StatelessWidget {
  const FlagBadge({super.key, required this.country, this.size = 48});

  final Country country;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = KissTheme.of(context);
    final code = country.code;
    final inner = size - 4; // leave a 2-px border ring
    final radius = BorderRadius.circular(KissRadius.md);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: radius,
        border: Border.all(color: t.stroke, width: 1),
      ),
      alignment: Alignment.center,
      child: code == null || code.length != 2
          ? Text(
              '??',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: size * 0.3,
                color: t.textMid,
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(KissRadius.md - 2),
              child: CountryFlag.fromCountryCode(
                code,
                height: inner,
                width: inner,
                shape: const RoundedRectangle(KissRadius.md - 2),
              ),
            ),
    );
  }
}
