import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/overview/model/overview.dart';
import 'package:shell/overview/model/overview_content.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/overview/provider/overview_state.dart';

void main() {
  const fileA = FileEntry(
    name: 'a.txt',
    path: DirectoryPath('/a.txt'),
    isDirectory: false,
    size: 1,
  );
  const fileB = FileEntry(
    name: 'b.txt',
    path: DirectoryPath('/b.txt'),
    isDirectory: false,
    size: 1,
  );

  ProviderContainer containerWithFiles() {
    final container = ProviderContainer(
      overrides: [
        filteredEntryListProvider(
          'test',
        ).overrideWithValue(const AsyncValue.data([fileA, fileB])),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(overviewStateProvider('test').notifier)
        .setSearchMode(SearchMode.file);
    return container;
  }

  OverviewState overview(ProviderContainer container) =>
      container.read(overviewStateProvider('test').notifier);

  Overview state(ProviderContainer container) =>
      container.read(overviewStateProvider('test'));

  group('OverviewState previews', () {
    test('selecting a file opens and selects a preview tab', () {
      final container = containerWithFiles();

      overview(container).selectIndex(0);

      final current = state(container);
      final preview = current.contentList.single as PreviewOverviewContent;
      expect(preview.entry, fileA);
      expect(current.selectedContentId, preview.contentId);
      expect(current.selectedContent, isA<PreviewOverviewContent>());
    });

    test('changing file while the preview is selected updates it in place', () {
      final container = containerWithFiles();

      overview(container).selectIndex(0);
      final idBefore = state(container).selectedContentId;

      overview(container).selectIndex(1);

      final current = state(container);
      expect(current.contentList, hasLength(1));
      expect(
        (current.contentList.single as PreviewOverviewContent).entry,
        fileB,
      );
      expect(current.selectedContentId, idBefore);
    });

    test('selecting another file from the Helm appends a second preview', () {
      final container = containerWithFiles();

      overview(container).selectIndex(0);
      overview(container).selectHelm();
      overview(container).selectIndex(1);

      final current = state(container);
      expect(
        current.contentList.whereType<PreviewOverviewContent>(),
        hasLength(2),
      );
      expect(current.selectedContentId, current.contentList.last.contentId);
    });

    test('closing the selected preview selects its neighbour', () {
      final container = containerWithFiles();

      overview(container).selectIndex(0);
      overview(container).selectHelm();
      overview(container).selectIndex(1);
      final second = state(container).contentList.last.contentId;

      overview(container).closeContent(second);

      final current = state(container);
      expect(current.contentList, hasLength(1));
      expect(current.selectedContentId, current.contentList.single.contentId);
    });

    test('closing the last content falls back to the Helm', () {
      final container = containerWithFiles();

      overview(container).selectIndex(0);
      overview(container).closeContent(state(container).selectedContentId);

      final current = state(container);
      expect(current.contentList, isEmpty);
      expect(current.selectedContentId, helmContentId);
      expect(current.selectedContent, isA<HelmOverviewContent>());
    });
  });
}
