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
    final keys = keysString.map(
      (e) => stringToKeyMap[e],
    );
    if (keys.contains(null)) {
      throw Exception('Invalid key in hotkey: $json');
    }
    return LogicalKeySet.fromSet(keys.cast<LogicalKeyboardKey>().toSet());
  }

  @override
  String toJson(LogicalKeySet object) {
    // Keys without a known name are dropped instead of serialized as `null`.
    final keys = object.keys.map(
      (e) => keyToStringMap[e],
    ).whereType<String>();
    return keys.join('+');
  }
}
