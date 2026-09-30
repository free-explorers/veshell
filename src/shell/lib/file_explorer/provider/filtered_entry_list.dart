import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/file_entry.dart';
import 'package:shell/file_explorer/provider/directory_listing.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'filtered_entry_list.g.dart';

/// The current directory's entries, filtered by the search box and sorted
/// directories-first then by name.
@riverpod
AsyncValue<List<FileEntry>> filteredEntryList(Ref ref, ScreenId screenId) {
  final fileExplorer = ref.watch(fileExplorerStateProvider(screenId));
  final directoryListing = ref.watch(
    directoryListingProvider(fileExplorer.path),
  );

  return directoryListing.whenData(
    (entryList) => filterAndSortFileEntries(
      entryList,
      filterText: fileExplorer.filterText,
      isShowingHidden: fileExplorer.isShowingHidden,
    ),
  );
}

/// Filters [entryList] by [filterText] and the hidden-files flag, then sorts
/// directories first and each group by case-insensitive name.
List<FileEntry> filterAndSortFileEntries(
  List<FileEntry> entryList, {
  required String filterText,
  required bool isShowingHidden,
}) {
  final normalizedFilter = filterText.toLowerCase();
  return entryList.where((entry) {
    if (!isShowingHidden && entry.name.startsWith('.')) {
      return false;
    }
    if (normalizedFilter.isEmpty) {
      return true;
    }
    return entry.name.toLowerCase().contains(normalizedFilter);
  }).toList()..sort((a, b) {
    if (a.isDirectory != b.isDirectory) {
      return a.isDirectory ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}
