import 'package:flutter_test/flutter_test.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/shared/widget/key_value_map_editor.dart';

void main() {
  late Map<String, String>? saved;

  setUp(() => saved = null);

  Widget app(
    Map<String, String> initial, {
    bool Function(String)? isValidKey,
  }) => MaterialApp(
    localizationsDelegates: shellLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: KeyValueMapEditor(
        initialValue: initial,
        keyLabel: 'Key',
        valueLabel: 'Value',
        errorMessage: 'Invalid key',
        isValidKey: isValidKey,
        onSave: (value) => saved = value,
      ),
    ),
  );

  testWidgets('seeds existing rows and saves the edited map', (tester) async {
    await tester.pumpWidget(app({'EXISTING': '1'}));
    expect(find.text('EXISTING'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pump();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(2), 'QT_STYLE_OVERRIDE');
    await tester.enterText(fields.at(3), 'Adwaita');

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, {'EXISTING': '1', 'QT_STYLE_OVERRIDE': 'Adwaita'});
  });

  testWidgets('an empty map starts with a row ready to fill', (tester) async {
    await tester.pumpWidget(app(const <String, String>{}));

    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('removing the last row leaves a row ready to fill', (
    tester,
  ) async {
    await tester.pumpWidget(app({'ONLY': '1'}));

    await tester.tap(find.byIcon(MdiIcons.delete).first);
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('a blank row is skipped', (tester) async {
    await tester.pumpWidget(app(const <String, String>{}));

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, isEmpty);
  });

  testWidgets('a duplicate key blocks the save', (tester) async {
    await tester.pumpWidget(app({'A': '1', 'B': '2'}));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'B');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, isNull);
    expect(find.text('Invalid key'), findsOneWidget);
  });

  testWidgets('isValidKey rejects a malformed key', (tester) async {
    await tester.pumpWidget(
      app(
        const <String, String>{},
        isValidKey: (key) => RegExp(r'^[A-Z_]+$').hasMatch(key),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'lower');
    await tester.enterText(fields.at(1), 'x');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, isNull);
    expect(find.text('Invalid key'), findsOneWidget);
  });
}
