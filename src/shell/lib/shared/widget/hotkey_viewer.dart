import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

final modKeys = {
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.superKey,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.shift,
};

/// Keys whose [LogicalKeyboardKey.keyLabel] is a raw character that reads as
/// blank inside a hotkey chip. Space renders as a literal space character, so
/// spell it out instead.
///
/// Kept non-`const` because [LogicalKeyboardKey] overrides `==`.
final _keyLabelOverrides = <LogicalKeyboardKey, String>{
  LogicalKeyboardKey.space: 'Space',
};

/// The display label for one key of a hotkey.
///
/// Falls back to [LogicalKeyboardKey.keyLabel], which already spells out the
/// non-printable keys ("Shift Left", "F1", …); only keys whose label is
/// invisible whitespace need an override.
String hotkeyKeyLabel(LogicalKeyboardKey key) =>
    _keyLabelOverrides[key] ?? key.keyLabel;

class HotkeyViewer extends StatelessWidget {
  const HotkeyViewer({required this.hotkey, super.key});
  final LogicalKeySet hotkey;

  @override
  Widget build(BuildContext context) {
    final keys = hotkey.keys.sorted((a, b) {
      return (modKeys.contains(a) ? -1 : 1).compareTo(
        modKeys.contains(b) ? -1 : 1,
      );
    });
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: keys
          .map(
            (value) => Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.black38,
              ),
              child: Text(hotkeyKeyLabel(value)),
            ),
          )
          .toList(),
    );
  }
}
