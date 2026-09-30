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

  /// Opens [path] from the listing. No entry is pre-selected.
  void openDirectory(DirectoryPath path) {
    if (state.path == path) {
      return;
    }
    state = state.copyWith(path: path, pendingSelectedPath: null);
  }

  /// Moves to the parent of the current directory, pre-selecting the directory
  /// we came from so it is highlighted in the parent's listing.
  void openParentDirectory() {
    final parent = state.path.parent;
    if (parent == null) {
      return;
    }
    _navigateTo(parent);
  }

  /// Jumps to an ancestor [path] from the breadcrumb, pre-selecting the child
  /// on the path back to the current directory.
  void openBreadcrumb(DirectoryPath path) {
    if (state.path == path) {
      return;
    }
    _navigateTo(path);
  }

  /// Clears a pending selection once the view has applied it.
  void clearPendingSelection() {
    if (state.pendingSelectedPath == null) {
      return;
    }
    state = state.copyWith(pendingSelectedPath: null);
  }

  void _navigateTo(DirectoryPath target) {
    state = state.copyWith(
      path: target,
      pendingSelectedPath: _childOnPath(from: state.path, target: target),
    );
  }

  /// The entry directly under [target] on the path to [from], or `null` when
  /// [from] is not below [target].
  DirectoryPath? _childOnPath({
    required DirectoryPath from,
    required DirectoryPath target,
  }) {
    final prefix = target.path == '/' ? '/' : '${target.path}/';
    if (!from.path.startsWith(prefix)) {
      return null;
    }
    final firstSegment = from.path.substring(prefix.length).split('/').first;
    if (firstSegment.isEmpty) {
      return null;
    }
    return DirectoryPath('$prefix$firstSegment');
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
