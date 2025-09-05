import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'screen_label.g.dart';

@riverpod
Future<String> screenLabel(Ref ref, ScreenId screenId) async {
  final screenState = ref.watch(screenStateProvider(screenId));
  if (screenState.label != null) {
    return screenState.label!;
  }
  final workspaceLabels = <String?>[];
  for (final workspaceId in screenState.workspaceList) {
    final workspaceState = ref.watch(workspaceStateProvider(workspaceId));
    var workspaceName =
        workspaceState.forcedCategory?.name ?? workspaceState.category?.name;
    if (workspaceName == null && workspaceState.tileableWindowList.isNotEmpty) {
      final appId = ref.watch(
        persistentWindowStateProvider(
          workspaceState.tileableWindowList.first,
        ).select(
          (value) => value.properties.appId,
        ),
      );

      final desktopEntry = await ref.watch(
        localizedDesktopEntryForIdProvider(appId).future,
      );
      if (desktopEntry != null) {
        workspaceName = desktopEntry.entries[DesktopEntryKey.name.string];
      }
    }
    workspaceLabels.add(workspaceName);
  }
  final notNullLabels = workspaceLabels.withNullsRemoved();
  if (notNullLabels.isEmpty) {
    return 'Empty';
  }

  return workspaceLabels.withNullsRemoved().join(', ');
}
