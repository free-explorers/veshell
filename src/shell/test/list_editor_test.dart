import 'package:flutter_test/flutter_test.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/shared/widget/list_editor.dart';

void main() {
  late List<String>? saved;

  setUp(() => saved = null);

  Widget app(List<String> initial, {bool Function(String)? isValidItem}) =>
      MaterialApp(
        localizationsDelegates: shellLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListEditor(
            initialValue: initial,
            itemLabel: 'Item',
            errorMessage: 'Invalid item',
            isValidItem: isValidItem,
            onSave: (value) => saved = value,
          ),
        ),
      );

  testWidgets('seeds existing rows and saves the edited list', (tester) async {
    await tester.pumpWidget(app(['us']));
    expect(find.text('us'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pump();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(1), 'ru');

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, ['us', 'ru']);
  });

  testWidgets('an empty list starts with a row ready to fill', (tester) async {
    await tester.pumpWidget(app(const <String>[]));

    expect(find.byType(TextField), findsNWidgets(1));
  });

  testWidgets('removing the last row leaves a row ready to fill', (
    tester,
  ) async {
    await tester.pumpWidget(app(['us']));

    await tester.tap(find.byIcon(MdiIcons.delete).first);
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(1));
    expect(find.text('us'), findsNothing);
  });

  testWidgets('a blank row is skipped', (tester) async {
    await tester.pumpWidget(app(const <String>[]));

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, isEmpty);
  });

  testWidgets('preserves the row order', (tester) async {
    await tester.pumpWidget(app(['ru', 'us']));

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, ['ru', 'us']);
  });

  testWidgets('a duplicate item blocks the save', (tester) async {
    await tester.pumpWidget(app(['us', 'ru']));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'us');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, isNull);
    expect(find.text('Invalid item'), findsOneWidget);
  });

  testWidgets('isValidItem rejects a malformed item', (tester) async {
    await tester.pumpWidget(
      app(
        const <String>[],
        isValidItem: (item) => RegExp(r'^[a-z]+$').hasMatch(item),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'us!');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, isNull);
    expect(find.text('Invalid item'), findsOneWidget);
  });
}
