import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer_desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_drawer.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_grid.dart';

void main() {
  LocalizedDesktopEntry entry(String name) => LocalizedDesktopEntry(
    desktopEntry: DesktopEntry(entries: const {}, id: name),
    entries: {DesktopEntryKey.name.string: name},
  );

  /// Pumps the drawer over the real filter, [width] wide, with the search
  /// field focused; returns the launched entries' names.
  Future<List<String?>> pumpDrawer(
    WidgetTester tester, {
    double width = 800,
    List<String> names = const ['Alpha', 'Beta', 'Gamma'],
  }) async {
    final launched = <String?>[];
    final container = ProviderContainer(
      overrides: [
        appDrawerDesktopEntriesProvider.overrideWith(
          (ref) async => [for (final name in names) entry(name)],
        ),
      ],
    );
    addTearDown(container.dispose);
    final searchFocusNode = FocusNode();
    addTearDown(searchFocusNode.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: AppDrawer(
                  onSelect: (e, _) async =>
                      launched.add(e.entries[DesktopEntryKey.name.string]),
                  searchFocusNode: searchFocusNode,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    return launched;
  }

  Future<void> pressEnter(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  String? selectedName(WidgetTester tester) => tester
      .widgetList<AppEntry>(find.byType(AppEntry))
      .where((e) => e.isSelected)
      .map((e) => e.desktopEntry.entries[DesktopEntryKey.name.string])
      .singleOrNull;

  String searchText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('Enter launches the first matching application', (tester) async {
    final launched = await pumpDrawer(tester);

    // Nothing launches until the search is accepted, and nothing is drawn as
    // selected before the keyboard is used.
    expect(launched, isEmpty);
    expect(selectedName(tester), isNull);

    await pressEnter(tester);

    expect(launched, ['Alpha']);
  });

  testWidgets('typing filters case-insensitively and Enter takes the match', (
    tester,
  ) async {
    final launched = await pumpDrawer(tester);

    await tester.enterText(find.byType(TextField), 'GAM');
    await tester.pumpAndSettle();
    expect(find.byType(AppEntry), findsOneWidget);
    expect(selectedName(tester), 'Gamma');

    await pressEnter(tester);

    expect(launched, ['Gamma']);
  });

  testWidgets('launching clears the search', (tester) async {
    await pumpDrawer(tester);

    await tester.enterText(find.byType(TextField), 'be');
    await tester.pumpAndSettle();
    await pressEnter(tester);

    expect(searchText(tester), isEmpty);
    expect(selectedName(tester), isNull);
  });

  testWidgets('launched applications get a card of their own', (tester) async {
    await pumpDrawer(tester);
    expect(find.byType(AppRow), findsNothing);

    await tester.enterText(find.byType(TextField), 'gam');
    await tester.pumpAndSettle();
    await pressEnter(tester);

    final row = find.byType(AppRow);
    expect(row, findsOneWidget);
    expect(
      tester
          .widgetList<AppEntry>(
            find.descendant(of: row, matching: find.byType(AppEntry)),
          )
          .map((e) => e.desktopEntry.entries[DesktopEntryKey.name.string]),
      ['Gamma'],
    );

    // The card leads the selection, and Down crosses into the grid below.
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(selectedName(tester), 'Alpha');
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(selectedName(tester), 'Gamma');

    // A search hides it: the most used lead the matches instead.
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();
    expect(find.byType(AppRow), findsNothing);
  });

  testWidgets('a search matching nothing says so', (tester) async {
    await pumpDrawer(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byType(AppEntry), findsNothing);
    expect(find.text('No applications match “zzz”'), findsOneWidget);

    // `Enter` on nothing keeps the keyboard in the search.
    await pressEnter(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
  });

  testWidgets('the clear button empties the search', (tester) async {
    await pumpDrawer(tester);
    expect(find.byTooltip('Clear search'), findsNothing);

    await tester.enterText(find.byType(TextField), 'be');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(searchText(tester), isEmpty);
    expect(find.byType(AppEntry), findsNWidgets(3));
  });

  testWidgets('Right and Left move the selection by one entry', (tester) async {
    final launched = await pumpDrawer(tester);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(selectedName(tester), 'Beta');
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    // Stops at the last entry.
    expect(selectedName(tester), 'Gamma');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(selectedName(tester), 'Beta');

    await pressEnter(tester);
    expect(launched, ['Beta']);
  });

  testWidgets('Left and Right edit the caret inside the search text', (
    tester,
  ) async {
    await pumpDrawer(tester);
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();

    // The caret is at the end: Left moves it, not the selection.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    final controller = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    expect(controller.selection.baseOffset, 0);
    expect(selectedName(tester), 'Alpha');
  });

  testWidgets('Down and Up move the selection by a row', (tester) async {
    // Narrow enough for two columns: Alpha Beta / Gamma.
    final launched = await pumpDrawer(tester, width: 300);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(selectedName(tester), 'Gamma');
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(selectedName(tester), 'Alpha');

    await press(tester, LogicalKeyboardKey.arrowDown);
    await pressEnter(tester);
    expect(launched, ['Gamma']);
  });

  group('the whole tile scrolls', () {
    final many = [
      for (var i = 0; i < 60; i++) 'App ${i.toString().padLeft(2, '0')}',
    ];

    ScrollPosition tileScroll(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        )
        .position;

    testWidgets('browsing scrolls the search away, typing brings it back', (
      tester,
    ) async {
      await pumpDrawer(tester, names: many);

      await tester.drag(find.byType(AppEntry).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tileScroll(tester).pixels, greaterThan(0));

      // The field kept the keyboard while out of view.
      final field = find.byType(TextField, skipOffstage: false);
      expect(field.hitTestable(), findsNothing);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      await tester.enterText(field, 'app 1');
      await tester.pumpAndSettle();
      expect(tileScroll(tester).pixels, 0);
    });

    testWidgets('the selection scrolls into view', (tester) async {
      await pumpDrawer(tester, names: many);

      for (var i = 0; i < 8; i++) {
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
      final selected = find.byWidgetPredicate(
        (w) => w is AppEntry && w.isSelected,
      );
      expect(tileScroll(tester).pixels, greaterThan(0));
      expect(
        tester.getRect(selected).bottom,
        lessThanOrEqualTo(tester.getSize(find.byType(AppDrawer)).height),
      );
    });

    testWidgets('a short list still fills the card to the bottom', (
      tester,
    ) async {
      await pumpDrawer(tester);

      final card = tester.renderObject<RenderSliver>(
        find.byType(DecoratedSliver),
      );
      final drawerHeight = tester.getSize(find.byType(AppDrawer)).height;
      // Shortest side 600 → 36 px margins; the card ends one margin above
      // the bottom.
      expect(
        card.constraints.precedingScrollExtent + card.geometry!.scrollExtent,
        closeTo(drawerHeight - 36, 0.5),
      );
    });
  });
}
