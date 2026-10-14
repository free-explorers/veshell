import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview_shortcuts.dart';
import 'package:shell/overview/widget/search/search_engine.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/shortcut_manager/widget/shortcut_manager.dart';

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
    // The overview no longer declares its own navigation bindings: the global
    // manager resolves the `navigation.*` bindings to `NavigateIntent`, which
    // the overview translates to framework focus traversal over the focusable
    // result rows.
    final navigation = <ShortcutActivator, Intent>{
      LogicalKeySet.fromSet({LogicalKeyboardKey.meta, LogicalKeyboardKey.keyW}):
          const NavigateIntent(NavigationDirection.up),
      LogicalKeySet.fromSet({LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS}):
          const NavigateIntent(NavigationDirection.down),
      LogicalKeySet.fromSet({LogicalKeyboardKey.meta, LogicalKeyboardKey.keyA}):
          const NavigateIntent(NavigationDirection.left),
      LogicalKeySet.fromSet({LogicalKeyboardKey.meta, LogicalKeyboardKey.keyD}):
          const NavigateIntent(NavigationDirection.right),
    };
    final container = ProviderContainer(
      overrides: [
        for (final text in filteredTexts)
          appDrawerFilteredDesktopEntriesProvider(
            text,
          ).overrideWith((ref) async => entryList),
        hotkeysActivatorProvider.overrideWithValue(navigation),
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
            child: VeshellShortcutManager(
              child: Scaffold(body: OverviewShortcuts(child: SearchEngine())),
            ),
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

  testWidgets('the list is per-row focus and Super+Up returns to the field', (
    tester,
  ) async {
    await pumpAppMode(tester);

    TextField field() => tester.widget<TextField>(find.byType(TextField));
    expect(field().focusNode?.hasFocus, isTrue);

    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
    }

    // Handing the keyboard to the list moves focus off the search field and
    // onto a row.
    await press(LogicalKeyboardKey.keyS);
    expect(field().focusNode?.hasFocus, isFalse);
    expect(FocusManager.instance.primaryFocus, isNotNull);

    // On the first row, up returns the keyboard to the field.
    await press(LogicalKeyboardKey.keyW);
    expect(field().focusNode?.hasFocus, isTrue);
  });

  testWidgets('the row highlight follows the keyboard focus', (tester) async {
    final container = await pumpAppMode(tester, filteredTexts: const ['', 'a']);

    Future<void> pressSuperS() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
    }

    Material rowMaterial() => tester.widget<Material>(
      find
          .ancestor(of: find.text('Alpha'), matching: find.byType(Material))
          .first,
    );

    // Typing selects the first result while the search field keeps the
    // keyboard: the row is selected but not painted.
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();
    expect(container.read(overviewStateProvider(screenId)).selectedIndex, 0);
    expect(rowMaterial().color, Colors.transparent);

    // Handing the keyboard to the list paints the focused row.
    await pressSuperS();
    expect(rowMaterial().color, isNot(Colors.transparent));
  });

  testWidgets('Super+Tab cycles the search mode', (tester) async {
    final container = await pumpAppMode(tester);

    SearchMode mode() =>
        container.read(overviewStateProvider(screenId)).searchMode;
    expect(mode(), SearchMode.application);

    Future<void> press(LogicalKeyboardKey key, {bool shift = false}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      if (shift) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      }
      await tester.sendKeyEvent(key);
      if (shift) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
    }

    await press(LogicalKeyboardKey.tab);
    expect(mode(), SearchMode.file);

    await press(LogicalKeyboardKey.tab, shift: true);
    expect(mode(), SearchMode.application);
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
