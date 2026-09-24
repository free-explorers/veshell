import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/meta_window/provider/process_info_state.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/matching_decision.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_decision_recorder.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'meta_window_manager.g.dart';

@riverpod
class MetaWindowManager extends _$MetaWindowManager {
  final Map<MetaWindowId, ProviderSubscription<bool>> _mappedSubscriptions = {};
  final Map<MetaWindowId, DateTime> _mappedAt = {};

  // Creations whose [MetaWindowState.create] is still awaiting (the desktop
  // entry lookup). If a removal arrives meanwhile, the window must be
  // destroyed as soon as the creation completes instead of being revived.
  final Set<MetaWindowId> _pendingCreated = {};
  final Set<MetaWindowId> _removedWhilePending = {};

  // Popups created through onNewMetaPopup, tracked so a patch or removal
  // racing past the creation event cannot mount the uninitialized provider.
  final Set<String> _popupIds = {};

  @override
  ISet<MetaWindowId> build() {
    ref.watch(platformManagerProvider).listen((next) {
      if (next case final MetaWindowCreatedEvent event) {
        onNewMetaWindow(event);
      }
      if (next case final MetaWindowPatchEvent event) {
        final patch = event.message;
        if (!state.contains(patch.id)) {
          geometryLog.warning('window patch $patch dropped for unknown window');
          return;
        }
        ref
            .read(metaWindowStateProvider(patch.id).notifier)
            .patch(patch, propagate: false)
            .then((_) {
              // A parent/modal/activation hint can arrive after the window was
              // already matched (Electron sets them late). Re-route it
              // as a dialog
              // while it is still inside its settle window.
              if (patch is UpdateParent ||
                  patch is UpdateIsModal ||
                  patch is UpdateActivatedBy) {
                _maybeRerouteAsDialog(patch.id);
              }
            });
      }
      if (next case final MetaWindowRemovedEvent event) {
        onMetaWindowRemoved(event.message.id);
      }
      if (next case final ProcessInfoEvent event) {
        ref.read(processInfoStateProvider.notifier).set(event.message);
      }
      if (next case final MetaPopupCreatedEvent event) {
        onNewMetaPopup(event);
      }
      if (next case final MetaPopupPatchEvent event) {
        if (!_popupIds.contains(event.message.id)) {
          geometryLog.warning(
            'popup patch dropped for unknown popup ${event.message.id}',
          );
          return;
        }
        ref
            .read(metaPopupStateProvider(event.message.id).notifier)
            .patch(event.message, propagate: false);
      }
      if (next case final MetaPopupRemovedEvent event) {
        onMetaPopupRemoved(event.message.id);
      }
    });

    return <MetaWindowId>{}.lock;
  }

  Future<void> onNewMetaWindow(MetaWindowCreatedEvent event) async {
    final metaWindowId = event.message.id;
    _pendingCreated.add(metaWindowId);
    try {
      await ref
          .read(metaWindowStateProvider(metaWindowId).notifier)
          .create(event.message);
    } finally {
      _pendingCreated.remove(metaWindowId);
    }

    // If the window was removed during the creation await, destroy it now
    // instead of leaking a revived zombie window (its providers were already
    // torn down and must not be re-added).
    if (_removedWhilePending.remove(metaWindowId)) {
      _destroyMetaWindowState(metaWindowId);
      geometryLog.info(
        'window=$metaWindowId creation completed after removal, dropped',
      );
      return;
    }
    if (state.contains(metaWindowId)) {
      return;
    }
    state = state.add(metaWindowId);

    _mappedSubscriptions[metaWindowId] = ref.listen(
      metaWindowStateProvider(metaWindowId).select((value) => value.mapped),
      (previouslyMapped, isMapped) {
        if (isMapped && previouslyMapped != isMapped) {
          onMetaWindowMapped(metaWindowId);
        }
      },
    );

    if (event.message.mapped) {
      onMetaWindowMapped(metaWindowId);
    }
  }

  void onMetaWindowMapped(MetaWindowId id, {int retryCount = 0}) {
    // Delays retry (Future.delayed) and interleaved events can land here
    // after the window was destroyed; a read would mount the uninitialized
    // provider.
    if (!state.contains(id)) {
      geometryLog.warning('window=$id mapped event dropped, no longer tracked');
      return;
    }
    final metaWindow = ref.read(metaWindowStateProvider(id));

    if (ref.read(metaWindowWindowMapProvider).get(id) != null) {
      return;
    }

    _mappedAt[id] = DateTime.now();

    final engine = ref.read(matchingEngineProvider.notifier);

    // A client-declared parent is authoritative: the window is a dialog of the
    // tile that owns that parent. Walk up dialog chains so a native window is
    // never nested under another dialog.
    if (metaWindow.parent != null) {
      final parentWindowId = ref
          .read(metaWindowWindowMapProvider)
          .get(metaWindow.parent!);
      if (parentWindowId == null) {
        // try again after a short delay because the parent window might
        // not be mapped yet
        if (retryCount < 10) {
          Future.delayed(const Duration(milliseconds: 100), () {
            onMetaWindowMapped(id, retryCount: retryCount + 1);
          });
        }
        return;
      }
      final owner = engine.rootTileFor(parentWindowId);
      _recordRouting(metaWindow, branch: 'clientParent', owner: owner);
      _createDialog(id, owner);
      return;
    }

    // Dialog hints without a client parent: a modal hint is authoritative. A
    // fixed size alone only counts when a real owner relation exists, so a
    // legitimate fixed-size toplevel is never turned into a dialog.
    if (metaWindow.isModal) {
      final owner = engine.resolveDialogOwnerIfAny(id);
      if (owner != null) {
        final rootOwner = engine.rootTileFor(owner);
        _recordRouting(metaWindow, branch: 'modal', owner: rootOwner);
        _createDialog(id, rootOwner);
        return;
      }
    }

    // A window opened from an owned window once the launch burst has settled
    // (any owner relation: activation, tracked provenance, process sibling)
    // attaches as a dialog of that owner instead of matching an empty same-app
    // tile. While a burst is still gathering the relation stays an "opened
    // from" hint so the gather/redistribute can run first. The recovery
    // lookups stay silent on this ordinary path.
    final WindowId? relationOwner;
    if (metaWindow.isFixedSized) {
      relationOwner = engine.dialogOwnerFromRelation(id);
    } else if (!engine.isLaunchBurstInProgressFor(id)) {
      relationOwner = engine.dialogOwnerFromRelation(id, log: false);
    } else {
      relationOwner = null;
    }
    if (relationOwner != null) {
      final rootOwner = engine.rootTileFor(relationOwner);
      _recordRouting(metaWindow, branch: 'relation', owner: rootOwner);
      _createDialog(id, rootOwner);
      return;
    }

    _recordRouting(metaWindow, branch: 'ordinary');
    engine.addMetaWindow(id);
  }

  /// Records the routing branch chosen for [metaWindow] for the debug recorder.
  void _recordRouting(
    MetaWindow metaWindow, {
    required String branch,
    WindowId? owner,
  }) {
    recordMatchingDecision(
      ref,
      () => MatchingDecision.routing(
        metaWindowId: metaWindow.id,
        appId: metaWindow.appId ?? '',
        pid: metaWindow.pid,
        parent: metaWindow.parent,
        activatedBy: metaWindow.activatedBy,
        isModal: metaWindow.isModal,
        isFixedSized: metaWindow.isFixedSized,
        branch: branch,
        ownerWindowId: owner == null ? null : windowIdKey(owner),
      ),
    );
  }

  void _createDialog(MetaWindowId id, WindowId owner) {
    ref
        .read(windowManagerProvider.notifier)
        .createDialogWindowForMetaWindow(id, owner);
  }

  /// Converts an already-matched window into a dialog when a client-declared
  /// parent, a modal hint or an activation relation arrives after mapping,
  /// while it is still inside its settle window.
  ///
  /// A parent or modal hint is authoritative and reroutes unconditionally. An
  /// activation relation only counts for a regular toplevel once the launch
  /// burst has settled, and only when it resolves to a real owner (it never
  /// falls back to the ordinary best candidate), matching [onMetaWindowMapped].
  void _maybeRerouteAsDialog(MetaWindowId id) {
    // A removal can race past the patch event between dispatches.
    if (!state.contains(id)) {
      geometryLog.warning('window=$id reroute dropped, no longer tracked');
      return;
    }
    final mappedAt = _mappedAt[id];
    if (mappedAt == null ||
        DateTime.now().difference(mappedAt).inMilliseconds >
            MAX_WINDOW_REASSOCIATION_TIME_MS) {
      return;
    }
    final metaWindow = ref.read(metaWindowStateProvider(id));
    final engine = ref.read(matchingEngineProvider.notifier);

    final WindowId? owner;
    if (metaWindow.isModal || metaWindow.parent != null) {
      owner = engine.resolveDialogOwnerIfAny(id);
    } else if (metaWindow.activatedBy != null &&
        !engine.isLaunchBurstInProgressFor(id)) {
      owner = engine.dialogOwnerFromRelation(id);
    } else {
      return;
    }
    if (owner == null) {
      return;
    }

    final currentOwner = ref.read(metaWindowWindowMapProvider).get(id);
    if (currentOwner == null || currentOwner is DialogWindowId) {
      return;
    }
    final rootOwner = engine.rootTileFor(owner);
    if (rootOwner == currentOwner) {
      return;
    }
    recordMatchingDecision(
      ref,
      () => MatchingDecision.reroute(
        metaWindowId: id,
        fromWindowId: windowIdKey(currentOwner),
        toWindowId: windowIdKey(rootOwner),
        reason: metaWindow.parent != null
            ? 'parent'
            : metaWindow.isModal
            ? 'modal'
            : 'activation',
      ),
    );
    (switch (currentOwner) {
              PersistentWindowId() => ref.read(
                persistentWindowStateProvider(currentOwner).notifier,
              ),
              DialogWindowId() => ref.read(
                dialogWindowStateProvider(currentOwner).notifier,
              ),
              EphemeralWindowId() => ref.read(
                ephemeralWindowStateProvider(currentOwner).notifier,
              ),
            }
            as WindowProviderMixin)
        .removeMetaWindow(id, shouldNotify: false);
    _createDialog(id, rootOwner);
  }

  void onMetaWindowRemoved(MetaWindowId id) {
    final windowId = ref.read(metaWindowWindowMapProvider).get(id);
    if (windowId != null) {
      (switch (windowId) {
                PersistentWindowId() => ref.read(
                  persistentWindowStateProvider(windowId).notifier,
                ),
                DialogWindowId() => ref.read(
                  dialogWindowStateProvider(windowId).notifier,
                ),
                EphemeralWindowId() => ref.read(
                  ephemeralWindowStateProvider(windowId).notifier,
                ),
              }
              as WindowProviderMixin)
          .onMetaWindowRemoved(id);
    }
    _mappedSubscriptions.remove(id)?.close();
    _mappedAt.remove(id);
    state = state.remove(id);

    // During this removal, MetaWindowState.create may still be awaiting in
    // onNewMetaWindow. Deferring the destroy keeps the removal ordered
    // against the late completion and the state provider never gets
    // re-initialized by a stray interceptor.
    if (_pendingCreated.contains(id)) {
      _removedWhilePending.add(id);
      return;
    }
    _destroyMetaWindowState(id);
  }

  /// Destroys the state provider for [id], tolerating the (never initialized)
  /// error state it throws in when the creation never reached this shell.
  void _destroyMetaWindowState(MetaWindowId id) {
    try {
      ref.read(metaWindowStateProvider(id).notifier).destroy();
    } on Object catch (error) {
      geometryLog.warning('destroy of window=$id failed', error);
    }
  }

  void onNewMetaPopup(MetaPopupCreatedEvent event) {
    _popupIds.add(event.message.id);
    ref
        .read(metaPopupStateProvider(event.message.id).notifier)
        .create(event.message);
  }

  void onMetaPopupRemoved(String id) {
    // A removal racing past the creation event would mount the
    // uninitialized provider, which throws by design.
    if (!_popupIds.remove(id)) {
      geometryLog.warning('popup=$id removal dropped, was not tracked');
      return;
    }
    ref.read(metaPopupStateProvider(id).notifier).destroy();
  }
}
