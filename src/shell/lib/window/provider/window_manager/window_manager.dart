import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/experimental/json_persist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_manager_state.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:uuid/uuid.dart';

part 'window_manager.g.dart';

final _log = Logger('WindowManager');

/// Window manager
@riverpod
@JsonPersist()
class WindowManager extends _$WindowManager {
  final _uuidGenerator = const Uuid();

  @override
  WindowManagerState build() {
    persist(
      storage: ref.watch(persistentStorageStateProvider).requireValue,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );

    return stateOrNull?.copyWith(
          windows:
              // Wheretype prevent adding other types later on
              // ignore: prefer_iterable_wheretype
              state.windows.where((id) => id is PersistentWindowId).toISet(),
        ) ??
        WindowManagerState(windows: <WindowId>{}.lock);
  }

  /// Create persistent window for desktop entry
  PersistentWindowId createPersistentWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
  ) {
    final windowId = PersistentWindowId(_uuidGenerator.v4());
    _log.info(
      'Creating new PersistentWindow $windowId',
    );
    final persistentWindow = PersistentWindow(
      windowId: windowId,
      properties: WindowProperties(
        appId: entry.desktopEntry.id ?? '',
        title: entry.entries[DesktopEntryKey.name.string],
      ),
    );

    ref
        .read(persistentWindowStateProvider(windowId).notifier)
        .initialize(persistentWindow);

    state = state.copyWith(windows: state.windows.add(windowId));
    return windowId;
  }

  /// Create persistent window for desktop entry
  EphemeralWindowId createEphemeralWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
    ScreenId screenId,
  ) {
    final windowId = EphemeralWindowId(_uuidGenerator.v4());
    _log.info(
      'Creating new EphemeralWindow $windowId',
    );
    final ephemeralWindow = EphemeralWindow(
      windowId: windowId,
      screenId: screenId,
      properties: WindowProperties(
        appId: entry.desktopEntry.id ?? '',
        title: entry.entries[DesktopEntryKey.name.string],
      ),
    );

    ref
        .read(ephemeralWindowStateProvider(windowId).notifier)
        .initialize(ephemeralWindow);

    state = state.copyWith(windows: state.windows.add(windowId));
    return windowId;
  }

  Future<PersistentWindowId> createPersistentWindowForMetaWindow({
    required MetaWindowId metaWindowId,
  }) async {
    // create a new window
    final windowId = PersistentWindowId(_uuidGenerator.v4());

    _log.info(
      'Creating new PersistentWindow $windowId for surface $metaWindowId',
    );

    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));

    final desktopEntryForSurface = await ref.read(
      localizedDesktopEntryForIdProvider(metaWindow.appId!).future,
    );

    final persistentWindow = PersistentWindow(
      windowId: windowId,
      properties: WindowProperties.fromMetaWindow(metaWindow).copyWith(
        appId: desktopEntryForSurface?.desktopEntry.id ?? metaWindow.appId!,
      ),
      metaWindowId: metaWindowId,
    );

    ref
        .read(persistentWindowStateProvider(windowId).notifier)
        .initialize(persistentWindow);

    state = state.copyWith(windows: state.windows.add(windowId));

    final currentScreenId = ref.read(focusedScreenProvider);
    final screenState = ref.read(screenStateProvider(currentScreenId));

    await ref
        .read(
          workspaceStateProvider(
            screenState.workspaceList[screenState.selectedIndex],
          ).notifier,
        )
        .addWindow(windowId);

    return windowId;
  }

  EphemeralWindowId createEphemeralWindowForMetaWindow({
    required MetaWindowId metaWindowId,
    required ScreenId screenId,
  }) {
    // create a new window
    final windowId = EphemeralWindowId(_uuidGenerator.v4());
    _log.info(
      'Creating new EphemeralWindow $windowId for surface $metaWindowId',
    );

    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
    final ephemeralWindow = EphemeralWindow(
      windowId: windowId,
      screenId: screenId,
      properties: WindowProperties.fromMetaWindow(metaWindow),
      metaWindowId: metaWindowId,
    );

    ref
        .read(ephemeralWindowStateProvider(windowId).notifier)
        .initialize(ephemeralWindow);

    state = state.copyWith(windows: state.windows.add(windowId));
    return windowId;
  }

  DialogWindowId createDialogWindowForMetaWindow(
    MetaWindowId metaWindowId,
    WindowId parentWindowId,
  ) {
    // create a new window
    final windowId = DialogWindowId(_uuidGenerator.v4());
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));

    _log.info(
      'Creating new DialogWindow $windowId for MetaWindow $metaWindow',
    );

    final dialogWindow = DialogWindow(
      windowId: windowId,
      metaWindowId: metaWindow.id,
      properties: WindowProperties.fromMetaWindow(metaWindow),
      parentWindowId: parentWindowId,
    );

    ref
        .read(dialogWindowStateProvider(windowId).notifier)
        .initialize(dialogWindow);

    state = state.copyWith(windows: state.windows.add(windowId));

    ref.read(dialogSetForWindowProvider(parentWindowId).notifier).add(windowId);
    return windowId;
  }

  void removeWindow(WindowId windowId) {
    _log.info(
      'Removing window: $windowId',
    );
    state = state.copyWith(windows: state.windows.remove(windowId));
  }
}
