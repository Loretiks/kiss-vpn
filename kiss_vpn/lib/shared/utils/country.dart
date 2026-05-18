/// Parses country flag emoji and codes out of free-form server names like
/// `"🇫🇮 🔥 Finland"` or `"🇷🇺 Whitelist RU 10ГБ/День"`.
///
/// Useful both for display (rendering the flag glyph in its own widget so
/// we can force the Segoe UI Emoji fallback) and for inferring the country
/// chip when the name doesn't have an explicit flag (we fall back to a
/// table of well-known country-name keywords).
class Country {
  Country({this.code, this.flag, required this.clean});

  /// Two-letter ISO country code (uppercase) — `FI`, `DE`, `RU`, etc.
  final String? code;

  /// The actual flag emoji as a string (one grapheme cluster: two regional
  /// indicator code points). `null` if we couldn't extract one.
  final String? flag;

  /// The server name with the flag stripped off (best-effort).
  final String clean;

  static final _flagRegex = RegExp(
    '([\u{1F1E6}-\u{1F1FF}])([\u{1F1E6}-\u{1F1FF}])',
    unicode: true,
  );

  /// Keyword → country code map for names that don't carry a flag emoji.
  static const _keywords = <String, String>{
    'finland': 'FI',
    'finlandia': 'FI',
    'финляндия': 'FI',
    'poland': 'PL',
    'польша': 'PL',
    'russia': 'RU',
    'россия': 'RU',
    'moscow': 'RU',
    'москва': 'RU',
    'germany': 'DE',
    'deutschland': 'DE',
    'германия': 'DE',
    'netherlands': 'NL',
    'нидерланды': 'NL',
    'amsterdam': 'NL',
    'usa': 'US',
    'united states': 'US',
    'сша': 'US',
    'sweden': 'SE',
    'швеция': 'SE',
    'norway': 'NO',
    'норвегия': 'NO',
    'france': 'FR',
    'франция': 'FR',
    'uk': 'GB',
    'london': 'GB',
    'лондон': 'GB',
    'turkey': 'TR',
    'турция': 'TR',
    'singapore': 'SG',
    'сингапур': 'SG',
    'japan': 'JP',
    'япония': 'JP',
    'estonia': 'EE',
    'эстония': 'EE',
    'latvia': 'LV',
    'латвия': 'LV',
    'lithuania': 'LT',
    'литва': 'LT',
    'czech': 'CZ',
    'чехия': 'CZ',
    'kazakhstan': 'KZ',
    'казахстан': 'KZ',
    'ukraine': 'UA',
    'украина': 'UA',
    'belarus': 'BY',
    'беларусь': 'BY',
  };

  static Country parse(String name) {
    final match = _flagRegex.firstMatch(name);
    if (match != null) {
      final flag = match.group(0)!;
      final r1 = flag.runes.first;
      final r2 = flag.runes.last;
      final letter1 = String.fromCharCode(r1 - 0x1F1E6 + 0x41);
      final letter2 = String.fromCharCode(r2 - 0x1F1E6 + 0x41);
      final code = '$letter1$letter2';
      final clean = name.replaceFirst(_flagRegex, '').trim();
      return Country(code: code, flag: flag, clean: clean);
    }

    final lower = name.toLowerCase();
    for (final entry in _keywords.entries) {
      if (lower.contains(entry.key)) {
        final code = entry.value;
        return Country(code: code, flag: _flagFromCode(code), clean: name);
      }
    }
    return Country(clean: name);
  }

  static String _flagFromCode(String code) {
    final c = code.toUpperCase();
    if (c.length != 2) return '';
    return String.fromCharCodes([
      c.codeUnitAt(0) - 0x41 + 0x1F1E6,
      c.codeUnitAt(1) - 0x41 + 0x1F1E6,
    ]);
  }
}
