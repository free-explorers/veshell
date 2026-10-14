import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shortcut_manager/model/string_to_key.dart';

class LogicalKeySetConverter implements JsonConverter<LogicalKeySet, String> {
  const LogicalKeySetConverter();

  @override
  LogicalKeySet fromJson(String json) {
    final keysString = json.split('+');
    final keys = keysString.map((e) => stringToKeyMap[e]);
    if (keys.contains(null)) {
      throw Exception('Invalid key in hotkey: $json');
    }
    return LogicalKeySet.fromSet(keys.cast<LogicalKeyboardKey>().toSet());
  }

  @override
  String toJson(LogicalKeySet object) {
    // Keys without a known name are dropped instead of serialized as `null`.
    final keys = object.keys.map((e) => keyToStringMap[e]).whereType<String>();
    return keys.join('+');
  }
}

/// A list of hotkeys bound to one action.
///
/// Accepts both the current array form (`["super+w", "super+up"]`) and the
/// legacy single-string form (`"super+w"`) so a hand-edited or older
/// `settings.json` keeps working. Malformed entries are dropped rather than
/// failing the whole settings load — the same policy as the single converter.
class LogicalKeySetListConverter
    implements JsonConverter<List<LogicalKeySet>, Object?> {
  const LogicalKeySetListConverter();

  static const _single = LogicalKeySetConverter();

  @override
  List<LogicalKeySet> fromJson(Object? json) {
    final values = switch (json) {
      final String single => <Object?>[single],
      final List<Object?> list => list,
      _ => const <Object?>[],
    };
    final result = <LogicalKeySet>[];
    for (final value in values) {
      if (value is! String || value.isEmpty) {
        continue;
      }
      try {
        result.add(_single.fromJson(value));
      } on Object catch (_) {
        // Skip the malformed entry instead of dropping the whole action.
      }
    }
    return result;
  }

  @override
  Object? toJson(List<LogicalKeySet> object) => object
      .map(_single.toJson)
      .where((binding) => binding.isNotEmpty)
      .toList();
}
