import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview_shortcuts.dart';
import 'package:shell/overview/widget/search/search_engine.dart';
import 'package:shell/screen/widget/current_screen_id.dart';

void main() {
  const screenId = 'test';

  List<LocalizedDesktopEntry> appEntries() => [
    LocalizedDesktopEntry(
      desktopEntry: const DesktopEntry(entries: {}),
      entries: {
        DesktopEntryKey.name.string: 'Alpha',
        DesktopEntryKey.comment.string: 'First',
      },
    ),
    LocalizedDesktopEntry(
      desktopEntry: const DesktopEntry(entries: {}),
      entries: {
        DesktopEntryKey.name.string: 'Beta',
        DesktopEntryKey.comment.string: 'Second',
      },
    ),
  ];

  /// Pumps the overview's search engine in application mode. Every text in
  /// [filteredTexts] resolves to the same two entries so typing a query does
  /// not depend on the real app drawer.
  Future<ProviderContainer> pumpAppMode(
    WidgetTester tester, {
    List<String> filteredTexts = const [''],
  }) async {
    final entryList = appEntries();
    final container = ProviderContainer(
      overrides: [
        for (final text in filteredTexts)
          appDrawerFilteredDesktopEntriesProvider(
            text,
          ).overrideWith((ref) async => entryList),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CurrentScreenId(
            screenId: screenId,
            child: Scaffold(body: OverviewShortcuts(child: SearchEngine())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Super+S moves the selection in application mode', (
    tester,
  ) async {
    final container = await pumpAppMode(tester);

    int? selected() =>
        container.read(overviewStateProvider(screenId)).selectedIndex;

    Future<void> pressSuperS() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
    }

    expect(selected(), isNull);
    await pressSuperS();
    expect(selected(), 0);
    await pressSuperS();
    expect(selected(), 1);
    // Clamps at the last entry instead of wrapping.
    await pressSuperS();
    expect(selected(), 1);
  });

  testWidgets('typing focuses the first result', (tester) async {
    final container = await pumpAppMode(tester, filteredTexts: const ['', 'a']);

    int? selected() =>
        container.read(overviewStateProvider(screenId)).selectedIndex;

    expect(selected(), isNull);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();

    expect(selected(), 0);
  });
}
