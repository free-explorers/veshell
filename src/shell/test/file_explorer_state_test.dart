import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/provider/file_explorer_state.dart';

void main() {
  test('navigating up pre-selects the directory we came from', () {
    final home = DirectoryPath(Platform.environment['HOME'] ?? '/');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(fileExplorerStateProvider('test').notifier);
    final child = DirectoryPath('${home.path}/workspace');

    notifier.openDirectory(child);
    expect(
      container.read(fileExplorerStateProvider('test')).pendingSelectedPath,
      isNull,
    );

    notifier.openParentDirectory();
    final state = container.read(fileExplorerStateProvider('test'));
    expect(state.path, home);
    expect(state.pendingSelectedPath, child);

    notifier.clearPendingSelection();
    expect(
      container.read(fileExplorerStateProvider('test')).pendingSelectedPath,
      isNull,
    );
  });

  test('a breadcrumb jump pre-selects the child on the way back', () {
    final home = DirectoryPath(Platform.environment['HOME'] ?? '/');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(fileExplorerStateProvider('test').notifier);
    final nested = DirectoryPath('${home.path}/a/b');

    notifier
      ..openDirectory(nested)
      ..openBreadcrumb(home);

    final state = container.read(fileExplorerStateProvider('test'));
    expect(state.path, home);
    expect(state.pendingSelectedPath, DirectoryPath('${home.path}/a'));
  });
}
