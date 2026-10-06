import 'package:flutter/widgets.dart';

/// Fontconfig family names from distribution packages (docs/dependencies.md).
/// Always include every shipped script: the language picker, app names and
/// notifications can contain text outside the current UI language.
List<String> shellFontFallbacks(Locale locale) {
  final cjk = switch (locale.languageCode) {
    'ja' => 'Noto Sans CJK JP',
    'ko' => 'Noto Sans CJK KR',
    'zh'
        when locale.scriptCode == 'Hant' ||
            const {'TW', 'HK', 'MO'}.contains(locale.countryCode) =>
      'Noto Sans CJK TC',
    _ => 'Noto Sans CJK SC',
  };

  return [
    'Noto Sans',
    'Noto Sans Arabic',
    'Noto Sans Bengali',
    'Noto Sans Devanagari',
    // Shared Han characters must prefer the UI locale's glyph forms.
    cjk,
    for (final family in const [
      'Noto Sans CJK SC',
      'Noto Sans CJK TC',
      'Noto Sans CJK JP',
      'Noto Sans CJK KR',
    ])
      if (family != cjk) family,
  ];
}
