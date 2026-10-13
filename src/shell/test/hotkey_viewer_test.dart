import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/hotkey_viewer.dart';

void main() {
  test('hotkeyKeyLabel spells out space but keeps other key labels', () {
    expect(hotkeyKeyLabel(LogicalKeyboardKey.space), 'Space');
    expect(hotkeyKeyLabel(LogicalKeyboardKey.keyA), 'A');
    expect(hotkeyKeyLabel(LogicalKeyboardKey.f1), 'F1');
  });

  testWidgets('a space binding renders as the word Space, not a blank chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HotkeyViewer(
            hotkey: LogicalKeySet.fromSet({
              LogicalKeyboardKey.superKey,
              LogicalKeyboardKey.space,
            }),
          ),
        ),
      ),
    );

    expect(find.text('Space'), findsOneWidget);
    expect(find.text(' '), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
