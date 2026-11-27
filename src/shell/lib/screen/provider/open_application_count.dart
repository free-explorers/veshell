import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/available_screen_list.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'open_application_count.g.dart';

/// How many of [screenId]'s tiles show a running application, across all of
/// its workspaces. A tile waiting to be relaunched does not count.
@riverpod
int openApplicationCountForScreen(Ref ref, ScreenId screenId) {
  final workspaceIds = ref.watch(
    screenStateProvider(screenId).select((screen) => screen.workspaceList),
  );
  var count = 0;
  for (final workspaceId in workspaceIds) {
    final windowIds = ref.watch(
      workspaceStateProvider(
        workspaceId,
      ).select((workspace) => workspace.tileableWindowList),
    );
    for (final windowId in windowIds) {
      final isRunning = ref.watch(
        persistentWindowStateProvider(
          windowId,
        ).select((window) => window.metaWindowId != null),
      );
      if (isRunning) {
        count++;
      }
    }
  }
  return count;
}

/// How many applications run on screens that no monitor shows.
@riverpod
int hiddenOpenApplicationCount(Ref ref) {
  var count = 0;
  for (final screenId in ref.watch(availableScreenListProvider)) {
    count += ref.watch(openApplicationCountForScreenProvider(screenId));
  }
  return count;
}
