import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

class ColorConverter implements JsonConverter<Color, String> {
  const ColorConverter();

  @override
  Color fromJson(String json) {
    final buffer = StringBuffer();
    if (json.length == 6) buffer.write('ff');
    buffer.write(json.startsWith('#') ? json.substring(1) : json);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  String toJson(Color object) =>
      '#${object.a}${object.r}${object.g}${object.b}';
}
