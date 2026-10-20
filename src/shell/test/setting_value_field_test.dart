import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/widget/primitive/setting_value_field.dart';

Widget _root(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('takes the keyboard and selects the current value', (
    tester,
  ) async {
    final committed = <int>[];
    await tester.pumpWidget(
      _root(
        SettingValueField<int>(
          text: '42',
          parse: int.tryParse,
          onCommit: committed.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );

    await tester.enterText(find.byType(TextField), '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(committed, [7]);
  });

  testWidgets('ActivateIntent validates the text', (tester) async {
    final committed = <int>[];
    await tester.pumpWidget(
      _root(
        SettingValueField<int>(
          text: '42',
          parse: int.tryParse,
          onCommit: committed.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '11');
    Actions.invoke(
      tester.element(find.byType(TextField)),
      const ActivateIntent(),
    );
    await tester.pump();

    expect(committed, [11]);
  });

  testWidgets('invalid text is not committed and shows an error', (
    tester,
  ) async {
    final committed = <int>[];
    await tester.pumpWidget(
      _root(
        SettingValueField<int>(
          text: '42',
          parse: int.tryParse,
          onCommit: committed.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not a number');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(committed, isEmpty);
    expect(find.text('Enter a valid value'), findsOneWidget);
  });
}
