import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:material_ui/material_ui.dart';

/// Converts a color to and from its settings form, `0xAARRGGBB`.
///
/// Settings files are also edited by hand and by scripts, so reading accepts
/// the common forms of a color: `0xAARRGGBB`, `0xRRGGBB` and `#RRGGBB`, the
/// last two opaque. Anything else, a number included, is a [FormatException].
class ColorConverter implements JsonConverter<Color, Object?> {
  const ColorConverter();

  static final _hexDigits = RegExp(r'^[0-9a-fA-F]+$');

  @override
  Color fromJson(Object? json) {
    if (json is! String) {
      throw FormatException(
        'Invalid color: expected a string such as "0xFF42A5F5" or "#42A5F5"',
        json,
      );
    }
    final digits = json.startsWith('0x')
        ? json.substring(2)
        : json.startsWith('#')
        ? json.substring(1)
        : null;
    final validLengths = json.startsWith('#') ? const [6] : const [6, 8];
    if (digits == null ||
        !validLengths.contains(digits.length) ||
        !_hexDigits.hasMatch(digits)) {
      throw FormatException(
        'Invalid color: expected "0xAARRGGBB", "0xRRGGBB" or "#RRGGBB"',
        json,
      );
    }
    final value = int.parse(digits, radix: 16);
    return Color(digits.length == 6 ? 0xFF000000 | value : value);
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
