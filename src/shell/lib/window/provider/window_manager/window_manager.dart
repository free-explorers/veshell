import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_children.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/provider/persistent_json_by_folder.dart';
import 'package:shell/wayland/model/request/close_window/close_window.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/workspace/provider/window_workspace_map.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:uuid/uuid.dart';

part 'window_manager.g.dart';

final _log = Logger('WindowManager');

/// Window manager
@Riverpod(keepAlive: true)
class WindowManager extends _$WindowManager {
  final _uuidGenerator = const Uuid();

  ISet<PersistentWindowId> get _persistentWindowSet =>
      state.whereType<PersistentWindowId>().toISet();

  ISet<EphemeralWindowId> get _ephemeralWindowSet =>
      state.whereType<EphemeralWindowId>().toISet();

  @override
  ISet<WindowId> build() {
    final intialSet = ref
            .read(persistentJsonByFolderProvider)
            .requireValue['Window']
            ?.keys
            .map<WindowId>(
              PersistentWindowId.new,
            )
            .toISet() ??
        <WindowId>{}.lock;

    return intialSet;
  }

  /// Get the Persistent Window Set
  ISet<PersistentWindowId> getPersistentWindowSet() => _persistentWindowSet;

  /// Get the Ephemeral Window Set
  ISet<EphemeralWindowId> getEphemeralWindowSet() => _ephemeralWindowSet;

  /// Create persistent window for desktop entry
  PersistentWindowId createPersistentWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
  ) {
    final windowId = PersistentWindowId(_uuidGenerator.v4());
    _log.info(
      'Creating new PersistentWindow $windowId for desktop entry $entry',
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

    state = state.add(windowId);
    return windowId;
  }

  /// Create persistent window for desktop entry
  EphemeralWindowId createEphemeralWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
    ScreenId screenId,
  ) {
    final windowId = EphemeralWindowId(_uuidGenerator.v4());
    _log.info(
      'Creating new EphemeralWindow $windowId for desktop entry $entry',
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

    state = state.add(windowId);
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

    state = state.add(windowId);

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

    state = state.add(windowId);
    return windowId;
  }

  void createDialogWindowForMetaWindow(
    MetaWindow metaWindow,
  ) {
    // create a new window
    final windowId = DialogWindowId(_uuidGenerator.v4());
    _log.info(
      'Creating new DialogWindow $windowId for MetaWindow $metaWindow',
    );

    final dialogWindow = DialogWindow(
      windowId: windowId,
      metaWindowId: metaWindow.id,
      properties: WindowProperties.fromMetaWindow(metaWindow),
      parentMetaWindowId: metaWindow.parent!,
    );

    ref
        .read(dialogWindowStateProvider(windowId).notifier)
        .initialize(dialogWindow);

    state = state.add(windowId);

    ref.read(metaWindowChildrenProvider(metaWindow.parent!).notifier).add(
          metaWindow.id,
        );
  }

  Future<void> onMetaWindowUnmapped(MetaWindowId metaWindowId) async {
    _log.info(
      'MetaWindow unmapped: $metaWindowId',
    );
    if (ref.read(metaWindowWindowMapProvider).get(metaWindowId)
        case final WindowId windowId) {
      switch (windowId) {
        case PersistentWindowId():
          ref
              .read(persistentWindowStateProvider(windowId).notifier)
              .onMetaWindowIsDestroyed(metaWindowId);

          final window = ref.read(persistentWindowStateProvider(windowId));

          if (window.metaWindowId == null) {
            final desktopEntryForSurface = await ref.read(
              localizedDesktopEntryForIdProvider(window.properties.appId)
                  .future,
            );

            if (desktopEntryForSurface == null) {
              _removeWindow(windowId);
            }
          }

        case DialogWindowId():
          final dialogWindow = ref.read(dialogWindowStateProvider(windowId));

          ref
              .read(
                metaWindowChildrenProvider(dialogWindow.parentMetaWindowId)
                    .notifier,
              )
              .remove(
                metaWindowId,
              );

          ref
              .read(dialogWindowStateProvider(windowId).notifier)
              .onMetaWindowIsDestroyed(metaWindowId);
          _removeWindow(windowId);
        case EphemeralWindowId():
          ref
              .read(ephemeralWindowStateProvider(windowId).notifier)
              .onMetaWindowIsDestroyed(metaWindowId);

          _removeWindow(windowId);
      }
    }
  }

  void _removeWindow(WindowId windowId) {
    _log.info(
      'Removing window: $windowId',
    );
    state = state.remove(windowId);
    switch (windowId) {
      case PersistentWindowId():
        final workspaceId = ref.read(windowWorkspaceMapProvider).get(windowId);
        if (workspaceId != null) {
          ref
              .read(workspaceStateProvider(workspaceId).notifier)
              .removeWindow(windowId);
        }
        ref.read(persistentWindowStateProvider(windowId).notifier).dispose();
      case DialogWindowId():
        ref.read(dialogWindowStateProvider(windowId).notifier).dispose();
      case EphemeralWindowId():
        final screenId =
            ref.read(ephemeralWindowStateProvider(windowId)).screenId;
        ref.read(ephemeralWindowStateProvider(windowId).notifier).dispose();
        ref
            .read(overviewStateProvider(screenId).notifier)
            .removeWindow(windowId);
    }
  }

  void closeWindow(WindowId windowId) {
    _log.info(
      'Closing window: $windowId',
    );
    switch (windowId) {
      case PersistentWindowId():
        final persistentWindow =
            ref.read(persistentWindowStateProvider(windowId));
        if (persistentWindow.metaWindowId != null) {
          closeWindowSurface(persistentWindow.metaWindowId!);
        } else {
          _removeWindow(windowId);
        }
      case DialogWindowId():
        closeWindowSurface(
          ref.read(dialogWindowStateProvider(windowId)).metaWindowId,
        );
      case EphemeralWindowId():
        final ephemeralWindow =
            ref.read(ephemeralWindowStateProvider(windowId));
        if (ephemeralWindow.metaWindowId != null) {
          closeWindowSurface(ephemeralWindow.metaWindowId!);
        } else {
          _removeWindow(windowId);
        }
    }
  }

  /// Close surface for window
  void closeWindowSurface(MetaWindowId metaWindowId) {
    _log.info(
      'Closing surface: $metaWindowId',
    );

    ref.read(waylandManagerProvider.notifier).request(
          CloseWindowRequest(
            message: CloseWindowMessage(
              metaWindowId: metaWindowId,
            ),
          ),
        );
  }
}
