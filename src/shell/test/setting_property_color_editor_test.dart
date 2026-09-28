import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'ColorCodeField finds MaterialLocalizations under a material_ui app',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ColorCodeField(
              color: Colors.red,
              onColorChanged: (_) {},
              onEditFocused: (_) {},
              requestFocus: false,
              focusedEditHasNoColor: false,
              colorCodeHasColor: true,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ColorCodeField), findsOneWidget);
    },
  );
}
