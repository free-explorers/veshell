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
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/window/model/dialog_area_entry.dart';
import 'package:shell/window/model/dialog_window.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/matching_decision.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_manager_state.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/dialog_set_for_window.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_decision_recorder.dart';
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
    final storage = ref.watch(persistentStorageStateProvider).requireValue;
    persist(
      storage,
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );

    return stateOrNull?.copyWith(
          windows: state.windows
              .whereType<PersistentWindowId>()
              // Drop ids whose state file is missing: such a tile cannot be
              // restored and reading its provider would throw forever.
              .where(
                (id) => storage.read(persistentWindowStorageKey(id)) != null,
              )
              // Widen back to `WindowId`: `whereType` would otherwise leave an
              // `ISet<PersistentWindowId>` behind and adding a dialog/ephemeral
              // id to it throws at runtime.
              .map<WindowId>((id) => id)
              .toISet(),
        ) ??
        WindowManagerState(windows: <WindowId>{}.lock);
  }

  /// Create persistent window for desktop entry
  PersistentWindowId createPersistentWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
  ) {
    final windowId = PersistentWindowId(_uuidGenerator.v4());
    _log.info('Creating new PersistentWindow $windowId');
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
    _log.info('Creating new EphemeralWindow $windowId');
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
    DisplayMode? displayMode,
  }) async {
    // create a new window
    final windowId = PersistentWindowId(_uuidGenerator.v4());

    _log.info(
      'Creating new PersistentWindow $windowId for surface $metaWindowId',
    );

    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));

    final desktopEntryForSurface = await ref.read(
      localizedDesktopEntryForIdProvider(metaWindow.appId ?? '').future,
    );

    final persistentWindow = PersistentWindow(
      windowId: windowId,
      properties: WindowProperties.fromMetaWindow(metaWindow).copyWith(
        appId:
            desktopEntryForSurface?.desktopEntry.id ?? (metaWindow.appId ?? ''),
      ),
      metaWindowId: metaWindowId,
      displayMode: displayMode ?? DisplayMode.maximized,
    );

    // The matcher chose this tile for the native window; if a late relation
    // re-routes the window into a dialog, this now-empty tile is disposable
    // (see `detachForReroute`).
    ref.read(persistentWindowStateProvider(windowId).notifier)
      ..initialize(persistentWindow)
      ..markAutoCreatedForMatching();

    state = state.copyWith(windows: state.windows.add(windowId));

    final focusedScreenId = ref.read(focusedScreenProvider);
    final screenIds = ref.read(screenManagerProvider).screenIds;
    final targetScreenId =
        focusedScreenId ?? (screenIds.isEmpty ? null : screenIds.first);

    if (targetScreenId == null) {
      _log.warning(
        'No screen available; window $windowId was created but not placed',
      );
      return windowId;
    }

    final screenState = ref.read(screenStateProvider(targetScreenId));

    await ref
        .read(
          workspaceStateProvider(
            screenState.workspaceList[screenState.selectedIndex],
          ).notifier,
        )
        .addWindow(windowId);

    return windowId;
  }

  DialogWindowId createDialogWindowForMetaWindow(
    MetaWindowId metaWindowId,
    WindowId parentWindowId,
  ) {
    // create a new window
    final windowId = DialogWindowId(_uuidGenerator.v4());
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));

    _log.info('Creating new DialogWindow $windowId for MetaWindow $metaWindow');

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

  /// Promotes the tile's sole dialog to its displayed window.
  ///
  /// Called when a tile loses the native window it displayed. If the tile is
  /// left owning exactly one dialog and that dialog is a regular toplevel (see
  /// [isExtractableDialog]), the dialog is the application's real window that
  /// was mistakenly attached as a dialog — Sweet Home 3D maps a transient
  /// "win0", the launch settles, then the real window opens just before the
  /// transient closes. Promoting it keeps the window visible in its own tile
  /// instead of burying it in the dialog area of a tile that shows nothing.
  ///
  /// A genuine dialog (modal, client-parented or fixed-size) is never promoted:
  /// it stays in the dialog area, shown over the tile's placeholder.
  void promoteSoleExtractableDialogForTile(WindowId tile) {
    if (tile is DialogWindowId) {
      return;
    }
    final dialogIds = ref.read(dialogSetForWindowProvider(tile));
    if (dialogIds.length != 1) {
      return;
    }
    final dialogId = dialogIds.first;
    final MetaWindowId metaWindowId;
    final MetaWindow metaWindow;
    try {
      metaWindowId = ref.read(dialogWindowStateProvider(dialogId)).metaWindowId;
      metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
    } on Object {
      // The dialog or its window is already gone; nothing to promote.
      return;
    }
    if (!isExtractableDialog(metaWindow)) {
      return;
    }

    _log.info(
      'Promoting sole dialog $dialogId (meta window $metaWindowId) to tile '
      '$tile: its displayed window left and the dialog is a regular toplevel',
    );
    recordMatchingDecision(
      ref,
      () => MatchingDecision.promote(
        windowId: windowIdKey(tile),
        dialogWindowId: dialogId.uuid,
        metaWindowId: metaWindowId,
      ),
    );

    // Detach the native window from the dialog silently (no rebroadcast may
    // route it back), then drop the now-empty dialog and hand the window to the
    // tile. The tile's display selection shows it and adopts its identity.
    ref.read(dialogWindowStateProvider(dialogId).notifier)
      ..removeMetaWindow(metaWindowId, shouldNotify: false)
      ..removeWindow();

    switch (tile) {
      case PersistentWindowId():
        ref
            .read(persistentWindowStateProvider(tile).notifier)
            .addMetaWindow(metaWindowId);
      case EphemeralWindowId():
        ref
            .read(ephemeralWindowStateProvider(tile).notifier)
            .addMetaWindow(metaWindowId);
      case DialogWindowId():
        break;
    }
  }

  void removeWindow(WindowId windowId) {
    _log.info('Removing window: $windowId');
    state = state.copyWith(windows: state.windows.remove(windowId));
  }
}
