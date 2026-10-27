import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

/// Restoring a screen must preserve the "empty workspace at the end" invariant.
///
/// The trailing workspace is the slot that creates the next workspace. It can
/// be absent from the persisted list when the previous session ended with
/// windows in what was the last workspace, and the workspace listener only
/// appends a new blank one after a later change. The restore path has to
/// normalize the list before the UI builds.
void main() {
  const screenId = 'screen-a';
  const populatedWorkspaceId = 'workspace-populated';

  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('veshell_screen_state_');
  });

  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  void writeJson(String key, Map<String, dynamic> data) {
    File('${directory.path}/$key.json').writeAsStringSync(jsonEncode(data));
  }

  void writeWindow(String id) {
    writeJson('persistent_window_$id', {
      'windowId': {'uuid': id, 'runtimeType': 'persistent'},
      'properties': {'appId': 'firefox'},
      'metaWindowId': null,
      'isWaitingForSurface': false,
      'displayMode': 'maximized',
      'customExec': null,
      'pid': null,
    });
  }

  void writeWorkspace(String id, List<String> windowIds) {
    writeJson('workspace_$id', {
      'workspaceId': id,
      'tileableWindowList': [
        for (final windowId in windowIds)
          {'uuid': windowId, 'runtimeType': 'persistent'},
      ],
      'selectedIndex': 0,
      'visibleLength': 1,
    });
  }

  void writeScreen(List<String> workspaceIds, {int selectedIndex = 0}) {
    writeJson('screen_$screenId', {
      'screenId': screenId,
      'workspaceList': workspaceIds,
      'selectedIndex': selectedIndex,
    });
  }

  Future<ProviderContainer> start() async {
    final container = ProviderContainer(
      overrides: [persistenceDirectoryProvider.overrideWithValue(directory)],
    );
    addTearDown(container.dispose);
    await container.read(persistentStorageStateProvider.future);
    final subscription = container.listen(
      screenStateProvider(screenId),
      (_, _) {},
    );
    addTearDown(subscription.close);
    return container;
  }

  test(
    'a restored last workspace with windows gets a fresh blank after it',
    () async {
      writeWindow('window-1');
      writeWorkspace(populatedWorkspaceId, ['window-1']);
      writeScreen([populatedWorkspaceId]);

      final container = await start();
      final screen = container.read(screenStateProvider(screenId));

      expect(screen.workspaceList, hasLength(2));
      expect(screen.workspaceList.first, populatedWorkspaceId);
      expect(screen.selectedIndex, 0);

      final freshWorkspaceId = screen.workspaceList.last;
      expect(freshWorkspaceId, isNot(populatedWorkspaceId));
      expect(
        container
            .read(workspaceStateProvider(freshWorkspaceId))
            .tileableWindowList,
        isEmpty,
      );
    },
  );

  test('an already empty trailing workspace is kept as is', () async {
    writeWorkspace(populatedWorkspaceId, const []);
    writeScreen([populatedWorkspaceId]);

    final container = await start();
    final screen = container.read(screenStateProvider(screenId));

    expect(screen.workspaceList, [populatedWorkspaceId]);
    expect(screen.selectedIndex, 0);
  });

  test('a fresh screen starts with a single empty workspace', () async {
    final container = await start();
    final screen = container.read(screenStateProvider(screenId));

    expect(screen.workspaceList, hasLength(1));
    expect(screen.selectedIndex, 0);
    expect(
      container
          .read(workspaceStateProvider(screen.workspaceList.single))
          .tileableWindowList,
      isEmpty,
    );
  });

  test('the selected workspace index is clamped to the list', () async {
    writeWorkspace(populatedWorkspaceId, const []);
    writeJson('screen_$screenId', {
      'screenId': screenId,
      'workspaceList': [populatedWorkspaceId],
      'selectedIndex': 4,
    });

    final container = await start();

    expect(container.read(screenStateProvider(screenId)).selectedIndex, 0);
  });
}
