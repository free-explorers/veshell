import 'package:json_annotation/json_annotation.dart';

/// One xkb option group the compositor knows, with its options.
///
/// Produced from the compositor's `get_keyboard_options` request, which reads
/// libxkbregistry. A group's [name] is not always the prefix of its options
/// (the compose group is named `Compose key`), so options are matched to their
/// group through the catalogue, never by prefix.
class KeyboardOptionGroup {
  const KeyboardOptionGroup({
    required this.name,
    required this.description,
    required this.allowsMultiple,
    required this.options,
  });

  factory KeyboardOptionGroup.fromJson(Map<String, dynamic> json) {
    final options = json['options'];
    return KeyboardOptionGroup(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      allowsMultiple: json['allowsMultiple'] as bool? ?? true,
      options: options is List
          ? [
              for (final option in options)
                if (option is Map)
                  KeyboardOption.fromJson(option.cast<String, dynamic>()),
            ]
          : const [],
    );
  }

  /// The xkb group name, e.g. `ctrl`.
  final String name;

  /// The label of the group, e.g. `Ctrl position`.
  final String description;

  /// Whether several options of the group can be set together.
  final bool allowsMultiple;

  final List<KeyboardOption> options;
}

/// One xkb option, e.g. `ctrl:nocaps` ("Caps Lock as Ctrl").
class KeyboardOption {
  const KeyboardOption({required this.name, required this.description});

  factory KeyboardOption.fromJson(Map<String, dynamic> json) => KeyboardOption(
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );

  /// The xkb option name stored in `keyboard.options`, e.g. `ctrl:nocaps`.
  final String name;

  /// The label shown in the picker.
  final String description;
}

/// Matches the option names the compositor accepts in `keyboard.options`
/// (`group:name`); anything else is dropped when the settings load.
final xkbOptionPattern = RegExp(r'^[A-Za-z0-9_.+-]+:[A-Za-z0-9_.+-]+$');

/// Reads the stored `keyboard.options` value: a list of option names, or the
/// xkb-native comma-separated string a hand-edited file may hold.
List<String> parseKeyboardOptions(Object? value) {
  final Iterable<Object?> entries = switch (value) {
    final List<Object?> list => list,
    final String string => string.split(','),
    _ => const [],
  };
  return [
    for (final entry in entries)
      if (entry is String && entry.trim().isNotEmpty) entry.trim(),
  ];
}

/// Reads and writes `keyboard.options` as a list of option names.
class KeyboardOptionsConverter implements JsonConverter<List<String>, dynamic> {
  const KeyboardOptionsConverter();

  @override
  List<String> fromJson(dynamic json) => parseKeyboardOptions(json);

  @override
  dynamic toJson(List<String> object) => object;
}
