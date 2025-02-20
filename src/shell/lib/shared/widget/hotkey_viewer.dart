import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class HotkeyViewer extends StatelessWidget {
  const HotkeyViewer({required this.hotkey, super.key});
  final LogicalKeySet hotkey;

  @override
  Widget build(BuildContext context) {
    final keys = hotkey.keys.sorted(
      (a, b) {
        return (modKeys.contains(a) ? -1 : 1)
            .compareTo(modKeys.contains(b) ? -1 : 1);
      },
    );
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
              child: Text(value.keyLabel),
            ),
          )
          .toList(),
    );
  }
}
