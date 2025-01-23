import 'package:flutter/material.dart';

class HotkeyViewer extends StatelessWidget {
  const HotkeyViewer({required this.hotkey, super.key});
  final String hotkey;

  @override
  Widget build(BuildContext context) {
    final keys = hotkey.split('+');
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
              child: Text(value.toUpperCase()),
            ),
          )
          .toList(),
    );
  }
}
