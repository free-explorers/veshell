import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/persistent_application_launcher.dart';

void main() {
  List<LocalizedDesktopEntry> appEntries() => [
    LocalizedDesktopEntry(
      desktopEntry: const DesktopEntry(entries: {}),
      entries: {DesktopEntryKey.name.string: 'Alpha'},
    ),
  ];

  /// Pumps the launcher tile itself: its own focus scope takes the keyboard for
  /// the tile, and the search field is what should end up with it.
  Future<ValueNotifier<bool>> pumpLauncher(
    WidgetTester tester, {
    required bool initial,
  }) async {
    final container = ProviderContainer(
      overrides: [
        appDrawerFilteredDesktopEntriesProvider(
          '',
        ).overrideWith((ref) async => appEntries()),
      ],
    );
    addTearDown(container.dispose);
    final selected = ValueNotifier(initial);
    addTearDown(selected.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: selected,
              builder: (context, isSelected, _) =>
                  PersistentApplicationSelector(
                    isSelected: isSelected,
                    onSelect: (_) {},
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return selected;
  }

  bool searchFieldHasFocus(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

  testWidgets('an unselected launcher does not grab the search focus', (
    tester,
  ) async {
    await pumpLauncher(tester, initial: false);

    expect(searchFieldHasFocus(tester), isFalse);
  });

  testWidgets('a launcher selected at mount focuses the search field', (
    tester,
  ) async {
    await pumpLauncher(tester, initial: true);

    expect(searchFieldHasFocus(tester), isTrue);
  });

  testWidgets('selecting an already-mounted launcher focuses the search field', (
    tester,
  ) async {
    // When the launcher is already on screen (e.g. the view is [window,
    // launcher]) it stays mounted while another tile is selected, so
    // `TextField.autofocus` no longer fires. Selecting it must still focus the
    // search field — and not just the tile's scope, which took the caret and
    // left typing filtering nothing.
    final selected = await pumpLauncher(tester, initial: false);
    expect(searchFieldHasFocus(tester), isFalse);

    selected.value = true;
    await tester.pumpAndSettle();

    expect(searchFieldHasFocus(tester), isTrue);
  });

  testWidgets('deselecting the launcher gives the keyboard back', (
    tester,
  ) async {
    final selected = await pumpLauncher(tester, initial: true);
    expect(searchFieldHasFocus(tester), isTrue);

    selected.value = false;
    await tester.pumpAndSettle();

    expect(searchFieldHasFocus(tester), isFalse);
  });
}
