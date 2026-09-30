import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/directory_listing.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/file_explorer/widget/file_explorer_view.dart';
import 'package:shell/screen/widget/current_screen_id.dart';

void main() {
  testWidgets('first tap selects immediately, second tap activates', (
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
    ];
    final container = ProviderContainer(
      overrides: [
        directoryListingProvider(home).overrideWith((ref) async => entryList),
      ],
    );
    addTearDown(container.dispose);

    final selectCalls = <int>[];
    final activateCalls = <int>[];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CurrentScreenId(
            screenId: 'test',
            child: Scaffold(
              body: FileExplorerView(
                searchText: '',
                onSelect: selectCalls.add,
                onActivate: activateCalls.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.txt'));
    await tester.pump();
    expect(selectCalls, [0]);
    expect(activateCalls, isEmpty);

    await tester.tap(find.text('a.txt'));
    await tester.pump();
    expect(activateCalls, [0]);
  });

  testWidgets('descending into a directory selects its first entry', (
    tester,
  ) async {
    final home = DirectoryPath(Platform.environment['HOME'] ?? '/');
    final child = DirectoryPath('${home.path}/child');
    final entryList = [
      FileEntry(
        name: 'first.txt',
        path: DirectoryPath('${child.path}/first.txt'),
        isDirectory: false,
        size: 1,
      ),
      FileEntry(
        name: 'second.txt',
        path: DirectoryPath('${child.path}/second.txt'),
        isDirectory: false,
        size: 2,
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        directoryListingProvider(
          home,
        ).overrideWith((ref) async => <FileEntry>[]),
        directoryListingProvider(child).overrideWith((ref) async => entryList),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(fileExplorerStateProvider('test').notifier)
        .openDirectory(child);

    final selectCalls = <int>[];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CurrentScreenId(
            screenId: 'test',
            child: Scaffold(
              body: FileExplorerView(searchText: '', onSelect: selectCalls.add),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(selectCalls, [0]);
  });

  testWidgets('a long path scrolls the breadcrumb to the current directory', (
    tester,
  ) async {
    final home = DirectoryPath(Platform.environment['HOME'] ?? '/');
    final deep = DirectoryPath(
      '${home.path}/a/very/long/chain/of/directories/that/overflows',
    );
    final container = ProviderContainer(
      overrides: [
        directoryListingProvider(
          deep,
        ).overrideWith((ref) async => <FileEntry>[]),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(fileExplorerStateProvider('test').notifier)
        .openDirectory(deep);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CurrentScreenId(
            screenId: 'test',
            child: Scaffold(
              body: SizedBox(
                width: 300,
                child: FileExplorerView(searchText: ''),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('file-explorer-breadcrumb')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, position.maxScrollExtent);
  });
}
