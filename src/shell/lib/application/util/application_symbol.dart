/// The symbol painted by the letter icon theme, styled like a periodic table
/// element: the first letter capitalized, the next one in lower case
/// (`Firefox` → `Fi`, `GIMP` → `Gi`).
///
/// Leading whitespace and punctuation are skipped, and so are separators
/// between the two characters (`7-Zip` → `7z`). Scripts without letter case,
/// such as CJK, keep a single character: two of them do not fit the badge and
/// there is no case contrast to read them as one symbol. A title without any
/// letter or digit keeps its first character instead of disappearing.
String applicationSymbol(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return '?';

  final characters = [
    for (final rune in trimmed.runes)
      if (_isLetterOrDigit(String.fromCharCode(rune)))
        String.fromCharCode(rune),
  ];
  if (characters.isEmpty) return _firstRune(trimmed.toUpperCase());

  final first = characters.first;
  final symbol = _firstRune(first.toUpperCase());
  if (characters.length < 2 || !_isCasedOrDigit(first)) return symbol;
  return symbol + _firstRune(characters[1].toLowerCase());
}

bool _isDigit(String character) => RegExp('[0-9]').hasMatch(character);

bool _isCased(String character) =>
    character.toLowerCase() != character.toUpperCase();

bool _isCasedOrDigit(String character) =>
    _isDigit(character) || _isCased(character);

/// Digits and cased letters. Letters from caseless scripts also count, so a
/// CJK title still gets its first character rather than `?`.
bool _isLetterOrDigit(String character) =>
    _isCasedOrDigit(character) ||
    RegExp(r'\p{L}', unicode: true).hasMatch(character);

String _firstRune(String value) => String.fromCharCode(value.runes.first);
