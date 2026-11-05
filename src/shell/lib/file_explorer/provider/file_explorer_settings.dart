import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/file_explorer_settings.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

part 'file_explorer_settings.g.dart';

const fileExplorerShowHiddenPath = 'files.showHidden';
const fileExplorerSortByPath = 'files.sortBy';
const fileExplorerSortDescendingPath = 'files.sortDescending';
const fileExplorerFoldersFirstPath = 'files.foldersFirst';
const fileExplorerShowDetailsPath = 'files.showDetails';

/// The persisted file explorer preferences, with the defaults of
/// [FileExplorerSettings] for a missing or malformed value.
@riverpod
FileExplorerSettings fileExplorerSettings(Ref ref) {
  const fallback = FileExplorerSettings();
  bool readBool(String path, {required bool fallback}) {
    final value = ref.watch(jsonValueByPathProvider(path));
    return value is bool ? value : fallback;
  }

  final sortBy = ref.watch(jsonValueByPathProvider(fileExplorerSortByPath));
  return FileExplorerSettings(
    showHidden: readBool(
      fileExplorerShowHiddenPath,
      fallback: fallback.showHidden,
    ),
    sortBy: FileSortKey.values.asNameMap()[sortBy] ?? fallback.sortBy,
    sortDescending: readBool(
      fileExplorerSortDescendingPath,
      fallback: fallback.sortDescending,
    ),
    foldersFirst: readBool(
      fileExplorerFoldersFirstPath,
      fallback: fallback.foldersFirst,
    ),
    showDetails: readBool(
      fileExplorerShowDetailsPath,
      fallback: fallback.showDetails,
    ),
  );
}

/// Persists one file explorer preference. [value] is a `bool`, or a
/// [FileSortKey] for [fileExplorerSortByPath].
void updateFileExplorerSetting(WidgetRef ref, String path, Object value) {
  ref
      .read(settingsPropertiesProvider.notifier)
      .updateProperty(path, value is FileSortKey ? value.name : value);
}
