import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

class ColorConverter implements JsonConverter<Color, String> {
  const ColorConverter();

  @override
  Color fromJson(String json) {
    // Ensure the input string is in the correct format
    if (!json.startsWith('0x')) {
      throw const FormatException(
        'Invalid color format. Expected format: 0xFF42A5F5',
      );
    }

    // Parse the hex string to an integer
    final colorValue = int.parse(json.substring(2), radix: 16);

    // Create and return the Color object
    return Color(colorValue);
  }

  @override
  String toJson(Color object) {
    final alpha = (object.a * 255).round();
    final red = (object.r * 255).round();
    final green = (object.g * 255).round();
    final blue = (object.b * 255).round();

    final alphaHex = alpha.toRadixString(16).padLeft(2, '0');
    final redHex = red.toRadixString(16).padLeft(2, '0');
    final greenHex = green.toRadixString(16).padLeft(2, '0');
    final blueHex = blue.toRadixString(16).padLeft(2, '0');

    return '0x$alphaHex$redHex$greenHex$blueHex';
  }
}
