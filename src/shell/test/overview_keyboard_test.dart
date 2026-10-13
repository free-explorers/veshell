import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/directory_listing.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/model/overview_content.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview_shortcuts.dart';
import 'package:shell/overview/widget/search/search_engine.dart';
import 'package:shell/screen/widget/current_screen_id.dart';

void main() {
  const screenId = 'test';

  DirectoryPath homePath() =>
      DirectoryPath(Platform.environment['HOME'] ?? '/');

  List<FileEntry> twoFiles(DirectoryPath home) => [
    FileEntry(
      name: 'a.txt',
      path: DirectoryPath('${home.path}/a.txt'),
      isDirectory: false,
      size: 1,
    ),
    FileEntry(
      name: 'b.txt',
      path: DirectoryPath('${home.path}/b.txt'),
      isDirectory: false,
      size: 1,
    ),
  ];

  Future<ProviderContainer> pumpFileMode(
    WidgetTester tester,
    DirectoryPath home,
    List<FileEntry> entryList,
  ) async {
    final container = ProviderContainer(
      overrides: [
        directoryListingProvider(home).overrideWith((ref) async => entryList),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(overviewStateProvider(screenId).notifier)
        .setSearchMode(SearchMode.file);

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

  Future<void> pressSuperS(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
  }

  testWidgets('Super+S moves the selection and clamps at the end', (
    tester,
  ) async {
    final home = homePath();
    final container = await pumpFileMode(tester, home, twoFiles(home));

    int? selected() =>
        container.read(overviewStateProvider(screenId)).selectedIndex;

    expect(selected(), isNull);

    await pressSuperS(tester);
    expect(selected(), 0);

    await pressSuperS(tester);
    expect(selected(), 1);

    // Clamps at the last entry instead of wrapping.
    await pressSuperS(tester);
    expect(selected(), 1);
  });

  testWidgets('a mouse selection keeps the Super shortcuts working', (
    tester,
  ) async {
    final home = homePath();
    final container = await pumpFileMode(tester, home, twoFiles(home));

    int? selected() =>
        container.read(overviewStateProvider(screenId)).selectedIndex;

    // Clicking a row selects it; the Super shortcuts keep working regardless
    // of where focus lands.
    await tester.tap(find.text('a.txt'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(selected(), 0);

    await pressSuperS(tester);
    expect(selected(), 1);
  });

  testWidgets('Super shortcuts fire when focus is outside the search field', (
    tester,
  ) async {
    final home = homePath();
    final entryList = twoFiles(home);
    final container = ProviderContainer(
      overrides: [
        directoryListingProvider(home).overrideWith((ref) async => entryList),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(overviewStateProvider(screenId).notifier)
        .setSearchMode(SearchMode.file);

    // A focusable sibling of the search engine stands in for a content tab or
    // an embedded window holding focus.
    final otherFocus = FocusNode(debugLabel: 'otherOverviewFocus');
    addTearDown(otherFocus.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CurrentScreenId(
            screenId: screenId,
            child: Scaffold(
              body: OverviewShortcuts(
                child: Column(
                  children: [
                    Focus(focusNode: otherFocus, child: const SizedBox()),
                    const Expanded(child: SearchEngine()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    otherFocus.requestFocus();
    await tester.pump();
    expect(otherFocus.hasPrimaryFocus, isTrue);

    await pressSuperS(tester);
    expect(container.read(overviewStateProvider(screenId)).selectedIndex, 0);
  });

  testWidgets('Escape closes the overview', (tester) async {
    final home = homePath();
    final container = await pumpFileMode(tester, home, twoFiles(home));

    bool displayed() =>
        container.read(overviewStateProvider(screenId)).isDisplayed;

    container.read(overviewStateProvider(screenId).notifier).toggle();
    await tester.pump();
    expect(displayed(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(displayed(), isFalse);
  });

  testWidgets('Enter activates the first result when none is selected', (
    tester,
  ) async {
    final home = homePath();
    final child = DirectoryPath('${home.path}/child');
    final container = ProviderContainer(
      overrides: [
        // The first entry (directories sort first) is a directory, so the
        // activation is observable as a directory change without a file opener.
        directoryListingProvider(home).overrideWith(
          (ref) async => [
            FileEntry(name: 'child', path: child, isDirectory: true, size: 0),
            FileEntry(
              name: 'b.txt',
              path: DirectoryPath('${home.path}/b.txt'),
              isDirectory: false,
              size: 1,
            ),
          ],
        ),
        directoryListingProvider(
          child,
        ).overrideWith((ref) async => <FileEntry>[]),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(overviewStateProvider(screenId).notifier)
        .setSearchMode(SearchMode.file);

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

    expect(
      container.read(overviewStateProvider(screenId)).selectedIndex,
      isNull,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    // Enter acted on the first entry, entering the directory.
    expect(container.read(fileExplorerStateProvider(screenId)).path, child);
  });

  testWidgets('typing in Files focuses the first match and opens its preview', (
    tester,
  ) async {
    final home = homePath();
    final container = await pumpFileMode(tester, home, twoFiles(home));

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();

    final overview = container.read(overviewStateProvider(screenId));
    expect(overview.selectedIndex, 0);
    expect(overview.selectedContent, isA<PreviewOverviewContent>());
  });
}
