import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/model/file_explorer.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'file_explorer_state.g.dart';

/// State of the overview's Files pane on one screen: where it is and what the
/// search box filters.
@riverpod
class FileExplorerState extends _$FileExplorerState {
  @override
  FileExplorer build(ScreenId screenId) {
    return FileExplorer(
      screenId: screenId,
      path: DirectoryPath(_homeDirectoryPath()),
    );
  }

  /// Opens [path] in the pane.
  void openDirectory(DirectoryPath path) {
    if (state.path == path) {
      return;
    }
    state = state.copyWith(path: path);
  }

  /// Moves to the parent of the current directory; a no-op at the root.
  void openParentDirectory() {
    final parent = state.path.parent;
    if (parent == null) {
      return;
    }
    state = state.copyWith(path: parent);
  }

  /// Applies the live filter typed in the overview search input.
  void setFilterText(String filterText) {
    if (state.filterText == filterText) {
      return;
    }
    state = state.copyWith(filterText: filterText);
  }
}

/// The user's home directory, or the filesystem root when `HOME` is unset.
String _homeDirectoryPath() {
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return home;
  }
  return '/';
}
