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
Future<String> screenLabel(Ref ref, ScreenId screenId) {
  final screenState = ref.watch(screenStateProvider(screenId));
  if (screenState.label != null) {
    return Future.value(screenState.label!);
  }

  // Every `ref.watch` happens here, before the first suspension point: an
  // auto-dispose provider must not touch its Ref after an async gap. Each
  // workspace's label resolves as a future and is awaited in [_joinLabels].
  final workspaceNames = <Future<String?>>[];
  for (final workspaceId in screenState.workspaceList) {
    final workspaceState = ref.watch(workspaceStateProvider(workspaceId));
    final categoryName =
        workspaceState.forcedCategory?.name ?? workspaceState.category?.name;
    if (categoryName != null || workspaceState.tileableWindowList.isEmpty) {
      workspaceNames.add(Future.value(categoryName));
      continue;
    }
    final appId = ref.watch(
      persistentWindowStateProvider(
        workspaceState.tileableWindowList.first,
      ).select((value) => value.properties.appId),
    );
    workspaceNames.add(
      ref
          .watch(localizedDesktopEntryForIdProvider(appId).future)
          .then(
            (desktopEntry) =>
                desktopEntry?.entries[DesktopEntryKey.name.string],
          ),
    );
  }
  return _joinLabels(workspaceNames);
}

Future<String> _joinLabels(List<Future<String?>> workspaceNames) async {
  final labels = await Future.wait(workspaceNames);
  final notNullLabels = labels.withNullsRemoved();
  if (notNullLabels.isEmpty) {
    return 'Empty';
  }
  return notNullLabels.join(', ');
}
