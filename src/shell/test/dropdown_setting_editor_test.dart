import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/widget/primitive/dropdown_setting_editor.dart';

const List<DropdownMenuItem<int>> _items = [
  DropdownMenuItem<int>(child: Text('Default')),
  DropdownMenuItem(value: 1, child: Text('One')),
  DropdownMenuItem(value: 2, child: Text('Two')),
];

Widget _root(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('selection is staged until the inline check is pressed', (
    tester,
  ) async {
    final draft = ValueNotifier<int?>(1);
    addTearDown(draft.dispose);
    final saved = <int?>[];
    await tester.pumpWidget(
      _root(
        ValueListenableBuilder<int?>(
          valueListenable: draft,
          builder: (context, value, _) => DropdownSettingEditor<int>(
            value: value,
            items: _items,
            onChanged: (value) => draft.value = value,
            onConfirm: () => saved.add(draft.value),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two').last);
    await tester.pumpAndSettle();
    expect(draft.value, 2);
    expect(saved, isEmpty);
    expect(find.byType(FilledButton), findsNothing);
    await tester.tap(find.byTooltip('Apply'));
    expect(saved, [2]);
    draft.value = 1;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .value,
      1,
    );
  });

  testWidgets('nullable default selections can be confirmed', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(
      _root(
        DropdownSettingEditor<int>(
          value: null,
          items: _items,
          hint: const Text('Default'),
          onChanged: (_) {},
          onConfirm: () => confirmed = true,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Apply'));
    expect(confirmed, isTrue);
  });

  testWidgets('saving disables selection and confirmation and shows progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      _root(
        DropdownSettingEditor<int>(
          value: 1,
          items: _items,
          saving: true,
          onChanged: (_) => fail('Selection should be disabled'),
          onConfirm: () => fail('Confirmation should be disabled'),
        ),
      ),
    );
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .onChanged,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
