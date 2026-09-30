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
    var state = container.read(fileExplorerStateProvider('test'));
    expect(state.pendingSelectedPath, isNull);
    // Descending asks the view to select the first entry of the new directory.
    expect(state.pendingSelectFirst, isTrue);

    notifier.openParentDirectory();
    state = container.read(fileExplorerStateProvider('test'));
    expect(state.path, home);
    expect(state.pendingSelectedPath, child);
    expect(state.pendingSelectFirst, isFalse);

    notifier.clearPendingSelection();
    expect(
      container.read(fileExplorerStateProvider('test')).pendingSelectedPath,
      isNull,
    );
  });

  test('clears the pending "select first" once the view applies it', () {
    final home = DirectoryPath(Platform.environment['HOME'] ?? '/');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(fileExplorerStateProvider('test').notifier);
    final target = DirectoryPath('${home.path}/workspace');

    notifier.openDirectory(target);
    expect(
      container.read(fileExplorerStateProvider('test')).pendingSelectFirst,
      isTrue,
    );

    notifier.clearPendingSelectFirst();
    expect(
      container.read(fileExplorerStateProvider('test')).pendingSelectFirst,
      isFalse,
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
