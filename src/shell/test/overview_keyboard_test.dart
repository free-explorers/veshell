import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/directory_listing.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/overview/provider/overview_state.dart';
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
          home: CurrentScreenId(
            screenId: screenId,
            child: Scaffold(body: SearchEngine()),
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

    // Clicking a row selects it and must not pull keyboard focus out of the
    // search engine, or the Super shortcuts stop firing.
    await tester.tap(find.text('a.txt'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(selected(), 0);

    await pressSuperS(tester);
    expect(selected(), 1);
  });
}
