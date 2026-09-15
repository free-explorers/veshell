import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

/// Shared behavior of the shell's window containers (persistent, dialog,
/// ephemeral) for owning native windows.
///
/// - **Owning:** [addMetaWindow] maps a [MetaWindowId] to this shell window
///   (`metaWindowWindowMapProvider`) and subscribes to its property changes;
///   the shell then renders whatever native window this tile decides to
///   display inside the tile.
/// - **Matching identity:** [MatchingInfo] — app id, title, class, startup
///   id, pid — is snapshotted once in [initialize] from the window
///   properties, the same values the matching engine scores. It is the
///   matching fingerprint that is *not* polluted by whatever the displayed
///   native window reports afterwards (that data flows to the persisted
///   `properties` instead — see `onMetaWindowDisplayedPropertiesChanged`
///   implementations).
/// - **Waiting:** [waitForSurface] arms the "newly launched" match bonus
///   (see `windowMatchingCost`); it is cleared as soon as a native window
///   attaches.
/// - **Display selection:** when a shell window owns several native windows,
///   the cheapest-to-match one is displayed and the overflow is dispatched
///   ([_dispatchExtraMetaWindows]) after a short settling delay, so bursts
///   of same-app windows don't re-route through half-open state.
mixin WindowProviderMixin<T extends Window> {
  T get state;
  set state(T value);
  Ref get ref;
  KeepAliveLink? _keepAliveLink;

  final Map<MetaWindowId, ProviderSubscription<MetaWindow>>
  _metaWindowSubscriptions = {};

  MetaWindowId? _displayedMetaWindowId;

  late MatchingInfo _matchingInfo;

  Timer? _debouncedTimer;

  /// Initialized a Window by keeping it alive and setting the surface.
  void initialize(T window) {
    _keepAliveLink?.close();
    _keepAliveLink = ref.keepAlive();
    state = window;
    _matchingInfo = MatchingInfo.fromWindowProperties(window.properties);
    if (state.metaWindowId != null) {
      addMetaWindow(state.metaWindowId!);
    }
  }

  /// Assign a surface to a Window subscribing to any changes.
  ///
  /// Also clears the launch-waiting bonus: from here on the tile believes
  /// its expectee arrived and matching scores rely on identity only.
  void addMetaWindow(MetaWindowId metaWindowId) {
    _matchingInfo = _matchingInfo.copyWith(waitingForAppSince: null);
    ref
        .read(metaWindowWindowMapProvider.notifier)
        .set(metaWindowId, state.windowId);
    _listenForMetaWindowChanges(metaWindowId);
    _onMetaWindowsChanges();
  }

  /// Recomputes which owned native window should be displayed.
  ///
  /// With a single owned window the choice is trivial. With several, the
  /// cheapest-to-match one wins: identity promises recorded at launch time
  /// (desktop-entry name, class) decide which native window best fits the
  /// tile.
  ///
  /// A 100 ms settling timer defers the *dispatch* of the overflow (see
  /// [_dispatchExtraMetaWindows]): restoring multiple windows arrives as a
  /// burst of events, dispatching on every event would bounce windows
  /// between placeholders before the set is complete. The delay also
  /// collapses the intermediate "all windows on one tile" state into a
  /// single redistribution.
  void _onMetaWindowsChanges() {
    MetaWindowId? newDisplayedMetaWindowId;
    // Reset the timer if changes occurs while we are waiting

    _debouncedTimer?.cancel();

    if (_metaWindowSubscriptions.isNotEmpty) {
      if (_metaWindowSubscriptions.length == 1) {
        newDisplayedMetaWindowId = _metaWindowSubscriptions.keys.first;
      } else {
        // pick the surface with the lest matching cost
        final metaWindowIdList = _metaWindowSubscriptions.keys.toList();
        final costs = metaWindowIdList.map((metaWindowId) {
          final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
          final metaWindowMatchInfo = MatchingInfo.fromMetaWindow(metaWindow);
          return windowMatchingCost(
            metaWindowMatchInfo,
            getMatchingInfo(),
            state,
          );
        }).toList();
        final minCost = costs.reduce(min);
        newDisplayedMetaWindowId = metaWindowIdList[costs.indexOf(minCost)];
      }

      // after this timer we need to dispatch any extra surfaces
      // to the best matches available or create new windows for them
      _debouncedTimer = Timer(const Duration(milliseconds: 100), () {
        if (_metaWindowSubscriptions.length > 1) {
          _dispatchExtraMetaWindows();
        }
      });
    }

    if (newDisplayedMetaWindowId != _displayedMetaWindowId) {
      _displayedMetaWindowId = newDisplayedMetaWindowId;
      print('new displayed meta window: $_displayedMetaWindowId');
      onCurrentlyDisplayedMetaWindowChanged(_displayedMetaWindowId);
    }
  }

  /// Redistributes owned native windows that this tile is not displaying.
  ///
  /// Runs after [_onMetaWindowsChanges]' settling timer, only when more than
  /// one window is owned. Typical trigger: Code OSS restoring all its
  /// windows at once on one tile — the overflow must reach the other
  /// same-app placeholders (each workspace keeps its own member).
  ///
  /// Algorithm (repeats until every owned surface found a home):
  ///
  /// 1. Ask the matching engine for the best *other* window for each
  ///    overflow surface, with already-assigned destinations excluded
  ///    (`excludedWindowIds` grows as assignments happen, and always starts
  ///    at the current window so a surface never re-attaches to the tile it
  ///    is overflowing from).
  /// 2. Resolve strongest matches first: a weak plan must not consume the
  ///    destination that a better-identified surface still needs.
  /// 3. Candidate found → reassign it there ; nothing found → attach it as a
  ///    **dialog** of the current tile, which is how application-opened
  ///    windows group with their origin (browser Ctrl+N style). Real dialogs
  ///    — windows reporting a native parent — are routed at mapping time and
  ///    never reach the dispatch loop.
  ///
  /// Batch examples:
  ///
  /// - Steam: main surface displayed; "Special Offers"/"Shutdown" overflow →
  ///   no other `steamwebhelper` candidate → dialogs under Steam.
  /// - Two Code OSS placeholders: overflow window 2 `appId == second
  ///   placeholder.appId` → reassignment, no dialog.
  Future<void> _dispatchExtraMetaWindows() async {
    final metaWindowsToDispatch = _metaWindowSubscriptions.keys
        .where((metaWindowId) => metaWindowId != _displayedMetaWindowId)
        .toSet();

    final excludedWindowIds = [state.windowId];
    print('Dispatching extra surfaces $metaWindowsToDispatch');

    while (metaWindowsToDispatch.isNotEmpty) {
      final bestMatchForMetaWindowMap = <MetaWindowId, (WindowId?, int?)>{};
      for (final metaWindowId in metaWindowsToDispatch) {
        bestMatchForMetaWindowMap[metaWindowId] = ref
            .read(matchingEngineProvider.notifier)
            .findBestWindowCandidateForMetaWindow(
              metaWindowId,
              excludedWindowIds: excludedWindowIds,
            );
      }
      // Resolve the strongest matches first so a weak match cannot consume a
      // candidate needed by a surface with better identity information.
      final sortedEntries = bestMatchForMetaWindowMap.entries.toList()
        ..sort(
          (entry1, entry2) => (entry1.value.$2 ?? INF_COST).compareTo(
            entry2.value.$2 ?? INF_COST,
          ),
        );

      for (final entry in sortedEntries) {
        final metaWindowId = entry.key;
        final (windowId, score) = entry.value;

        // If there is no windowId, create a new dialog window for it
        if (windowId == null) {
          print('Creating new dialog window for metaWindow $metaWindowId');
          removeMetaWindow(metaWindowId, shouldNotify: false);
          final newWindowId = ref
              .read(windowManagerProvider.notifier)
              .createDialogWindowForMetaWindow(metaWindowId, state.windowId);

          excludedWindowIds.add(newWindowId);
          metaWindowsToDispatch.remove(metaWindowId);
        } else {
          // If a bestmatch was already found skip to next iteration
          // Else
          if (!excludedWindowIds.contains(windowId)) {
            removeMetaWindow(metaWindowId, shouldNotify: false);
            switch (windowId) {
              case PersistentWindowId():
                ref
                    .read(persistentWindowStateProvider(windowId).notifier)
                    .addMetaWindow(metaWindowId);
              case EphemeralWindowId():
                ref
                    .read(ephemeralWindowStateProvider(windowId).notifier)
                    .addMetaWindow(metaWindowId);
              case _: // ignore: no_default_cases
            }
            excludedWindowIds.add(windowId);
            metaWindowsToDispatch.remove(metaWindowId);
          }
        }
      }
    }
  }

  void removeMetaWindow(MetaWindowId metaWindowId, {bool shouldNotify = true}) {
    _closeMetaWindowSubscription(metaWindowId);
    ref.read(metaWindowWindowMapProvider.notifier).unset(metaWindowId);
    if (shouldNotify) {
      _onMetaWindowsChanges();
    }
  }

  /// Identity watchers mirroring compositor property patches into the
  /// scheduler: only fields the matcher consumes re-trigger the display
  /// selection, geometry churn does not re-route windows.
  ///
  /// The displayed surface additionally streams property updates to
  /// [onMetaWindowDisplayedPropertiesChanged] (title, pid... used by the
  /// persisted representation), never the matching snapshot itself.
  void _listenForMetaWindowChanges(MetaWindowId surfaceId) {
    _closeMetaWindowSubscription(surfaceId);

    _metaWindowSubscriptions[surfaceId] = ref.listen(
      metaWindowStateProvider(surfaceId),
      (previous, next) {
        if (previous == null ||
            previous.appId != next.appId ||
            previous.title != next.title ||
            previous.windowClass != next.windowClass ||
            previous.startupId != next.startupId ||
            previous.pid != next.pid ||
            previous.mapped != next.mapped ||
            previous.parent != next.parent) {
          _onMetaWindowsChanges();
        }
        if (surfaceId == _displayedMetaWindowId) {
          onMetaWindowDisplayedPropertiesChanged(next);
        }
      },
    );
  }

  /// Launches the desktop entry this tile stands for, attributing anything
  /// the application starts to this tile.
  ///
  /// Requires the tile's persisted `appId` to resolve to a desktop entry.
  /// Custom-command launches live in `PersistentWindowState` (they use the
  /// custom exec string instead).
  Future<Process?> launchSelf() async {
    final entry = await ref.read(
      localizedDesktopEntryForIdProvider(state.properties.appId).future,
    );

    if (entry == null) {
      return null;
    }
    return ref
        .read(appLaunchProvider.notifier)
        .launchApplication(
          LaunchConfig.fromDesktopEntry(entry.desktopEntry),
          trackedWindowId: state.windowId,
        );
  }

  void onMetaWindowDisplayedPropertiesChanged(MetaWindow metaWindow);

  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId);

  MatchingInfo getMatchingInfo() => _matchingInfo;

  void waitForSurface(int? pid) {
    _matchingInfo = _matchingInfo.copyWith(
      waitingForAppSince: DateTime.now(),
      pid: pid,
    );
  }

  void onMetaWindowRemoved(MetaWindowId metaWindowId) {
    removeMetaWindow(metaWindowId);
  }

  void _closeMetaWindowSubscription(MetaWindowId metaWindowId) {
    final subscription = _metaWindowSubscriptions[metaWindowId];
    if (subscription != null) {
      subscription.close();
      _metaWindowSubscriptions.remove(metaWindowId);
    }
  }

  void dispose() {
    _keepAliveLink?.close();
  }

  void closeWindow() {
    for (final metaWindowId in _metaWindowSubscriptions.keys) {
      ref.read(metaWindowStateProvider(metaWindowId).notifier).requestToClose();
    }
  }

  void removeWindow();
}
