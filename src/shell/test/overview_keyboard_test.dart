import 'dart:io';

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

  testWidgets('Super+S moves the selection and clamps at the end', (
    tester,
  ) async {
    final home = DirectoryPath(Platform.environment['HOME'] ?? '/');
    final entryList = [
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

    DirectoryPath? selected() =>
        container.read(overviewStateProvider(screenId)).selectedPath;

    Future<void> pressSuperS() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
    }

    expect(selected(), isNull);

    await pressSuperS();
    expect(selected(), entryList[0].path);

    await pressSuperS();
    expect(selected(), entryList[1].path);

    // Clamps at the last entry instead of wrapping.
    await pressSuperS();
    expect(selected(), entryList[1].path);
  });
}
