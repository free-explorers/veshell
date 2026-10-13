/// One layout (optionally with a variant) the compositor can compile.
///
/// Produced from the compositor's `get_keyboard_layouts` request, which reads
/// libxkbregistry. Mirrors the `rxkb_layout` fields: `layout`/`variant` (e.g.
/// `us`/`altgr-intl`), a `description` label, and the ISO language/country
/// codes the entry maps to.
class KeyboardLayoutOption {
  const KeyboardLayoutOption({
    required this.layout,
    required this.variant,
    required this.description,
    this.brief = '',
    this.iso639 = const [],
    this.iso3166 = const [],
  });

  factory KeyboardLayoutOption.fromJson(Map<String, dynamic> json) =>
      KeyboardLayoutOption(
        layout: json['layout'] as String? ?? '',
        variant: json['variant'] as String? ?? '',
        description: json['description'] as String? ?? '',
        brief: json['brief'] as String? ?? '',
        iso639: _stringList(json['iso639']),
        iso3166: _stringList(json['iso3166']),
      );

  /// The xkb layout name, e.g. `us`.
  final String layout;

  /// The xkb variant name, e.g. `altgr-intl`; empty for a base layout.
  final String variant;

  /// The label shown in the picker, e.g. `English (US)`.
  final String description;

  /// The ISO 639-1 language code, e.g. `en`.
  final String brief;

  /// ISO 639 language codes the layout maps to.
  final List<String> iso639;

  /// ISO 3166 country codes the layout maps to.
  final List<String> iso3166;

  /// The xkb-native entry stored in `keyboard.layout`: `us` or
  /// `us(altgr-intl)`, the syntax `XkbConfig::layout` accepts.
  String get entry => variant.isEmpty ? layout : '$layout($variant)';

  static List<String> _stringList(dynamic value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const [];
}

/// Splits the stored comma-separated xkb layout list into its entries.
///
/// The value is xkb-native (`us(altgr-intl),ru`): a layout may carry its
/// variant in parentheses, and a variant never contains a comma, so
/// splitting on commas recovers one entry per layout.
List<String> parseKeyboardLayouts(String? value) {
  if (value == null) return const [];
  return value
      .split(',')
      .map((layout) => layout.trim())
      .where((layout) => layout.isNotEmpty)
      .toList();
}
