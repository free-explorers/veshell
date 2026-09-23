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
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/matching_decision.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_decision_recorder.dart';
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
/// - **Waiting:** [waitForSurface] arms the "newly launched" gather bonus
///   (see `windowMatchingCost`); it stays armed for the whole burst and is
///   cleared at the burst settle.
/// - **Redistribution:** when a shell window owns several native windows, the
///   cheapest-to-match one is displayed and the rest are redistributed
///   ([_redistributeOwnedMetaWindows]) after a short settling delay, so bursts
///   of same-app windows don't re-route through half-open state.
/// Maximum automatic reopen attempts for a launched tile whose gathered
/// windows all ended up better matched by siblings. Bounded so a misbehaving
/// application cannot loop.
const _maxLaunchReopenAttempts = 1;

/// Added to the display cost of a fixed-size native window so a tile prefers
/// the application's real (resizable) window over a transient fixed-size
/// helper (e.g. Discord's "Discord Updater" while the real "Discord" window is
/// present). Larger than a title mismatch (50) so it overrides a stale stored
/// title that exactly matches the helper, smaller than `INF_COST`.
const _fixedSizeDisplayPenalty = 100;

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

  /// Whether this tile is the origin of an in-flight launch burst: it gathers
  /// the whole burst (waiting bonus armed), then at the settle it dispatches
  /// the windows a sibling matches better and keeps the rest. Cleared at the
  /// burst settle. See [_finalizeLaunchBurst].
  bool _launchOrigin = false;

  /// Whether the origin owned a native window at some point during this
  /// launch. Reopening only happens when a window arrived and then left, never
  /// when the launch produced no window at all.
  bool _everOwnedWindow = false;
  int _reopenAttempts = 0;

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

  /// Assign a native window to this tile and subscribe to its changes.
  ///
  /// While this tile is a launch origin the waiting bonus stays armed, so the
  /// whole burst keeps gathering here; it is cleared at the burst settle, after
  /// which ownership follows the title (see [_finalizeLaunchBurst]).
  void addMetaWindow(MetaWindowId metaWindowId) {
    if (_launchOrigin) {
      _everOwnedWindow = true;
    } else {
      _matchingInfo = _matchingInfo.copyWith(waitingForAppSince: null);
    }
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
  /// A 100 ms settling timer defers the *dispatch decision*: a burst arrives
  /// as a series of events and dispatching on every event would bounce windows
  /// between placeholders before titles have settled. A launch origin always
  /// arms it (to finalize the gather), a non-origin tile only when it has an
  /// overflow to dispatch.
  void _onMetaWindowsChanges() {
    _debouncedTimer?.cancel();
    _recomputeDisplayedMetaWindow();

    if (_launchOrigin || _metaWindowSubscriptions.length > 1) {
      _debouncedTimer = Timer(const Duration(milliseconds: 100), () {
        if (_launchOrigin) {
          _finalizeLaunchBurst();
        } else if (_metaWindowSubscriptions.length > 1) {
          _redistributeOwnedMetaWindows();
        }
      });
    }
  }

  /// Picks the displayed native window among the owned ones without arming any
  /// timer.
  void _recomputeDisplayedMetaWindow() {
    MetaWindowId? newDisplayedMetaWindowId;

    if (_metaWindowSubscriptions.isNotEmpty) {
      if (_metaWindowSubscriptions.length == 1) {
        newDisplayedMetaWindowId = _metaWindowSubscriptions.keys.first;
      } else {
        final metaWindowIdList = _metaWindowSubscriptions.keys.toList();
        final costs = metaWindowIdList.map((metaWindowId) {
          final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
          return _displayCost(metaWindow);
        }).toList();
        final totals = [
          for (final cost in costs) cost.cost.total + cost.fixedSizePenalty,
        ];
        final minCost = totals.reduce(min);
        newDisplayedMetaWindowId = metaWindowIdList[totals.indexOf(minCost)];
      }
    }

    if (newDisplayedMetaWindowId != _displayedMetaWindowId) {
      _displayedMetaWindowId = newDisplayedMetaWindowId;
      print('new displayed meta window: $_displayedMetaWindowId');
      _recordDisplayDecision(_displayedMetaWindowId);
      onCurrentlyDisplayedMetaWindowChanged(_displayedMetaWindowId);
    }

    // A settled single-window tile adopts the displayed window's identity even
    // when the displayed id did not change. At the burst settle the tile flips
    // from launch origin to settled while keeping the same window; missing that
    // adoption would leave `_matchingInfo` stale relative to the title the tile
    // actually shows, and the next burst would then swap siblings.
    final displayedMetaWindowId = _displayedMetaWindowId;
    if (displayedMetaWindowId != null && _canAdoptDisplayedIdentity) {
      _syncMatchingInfo(
        ref.read(metaWindowStateProvider(displayedMetaWindowId)),
      );
    }
  }

  /// Display-selection cost for one owned native window.
  ///
  /// This is the matcher's identity cost plus [_fixedSizeDisplayPenalty] for a
  /// fixed-size window. The penalty only orders windows *within* this tile
  /// (the matcher's ordinary matching and the sibling redistribution use the
  /// unpenalised cost): when a tile owns both a fixed-size helper and the
  /// application's real window, the real one is displayed and the helper is
  /// the better leftover to turn into a dialog.
  ({MatchingCost cost, int fixedSizePenalty}) _displayCost(
    MetaWindow metaWindow,
  ) {
    final cost = windowMatchingCost(
      MatchingInfo.fromMetaWindow(metaWindow),
      getMatchingInfo(),
      state,
    );
    return (
      cost: cost,
      fixedSizePenalty: metaWindow.isFixedSized ? _fixedSizeDisplayPenalty : 0,
    );
  }

  /// Records which owned window the tile chose to display, with the cost and
  /// fixed-size penalty of each candidate (debug recorder only).
  void _recordDisplayDecision(MetaWindowId? displayed) {
    recordMatchingDecision(
      ref,
      () => MatchingDecision.display(
        windowId: windowIdKey(state.windowId),
        displayedWindowId: displayed,
        owned: [
          for (final metaWindowId in _metaWindowSubscriptions.keys)
            _displayCostEntry(metaWindowId),
        ],
      ),
    );
  }

  Map<String, Object?> _displayCostEntry(MetaWindowId metaWindowId) {
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
    final cost = _displayCost(metaWindow);
    return {
      'metaWindowId': metaWindowId,
      'cost': cost.cost.toJson(),
      'fixedSizePenalty': cost.fixedSizePenalty,
    };
  }

  /// Whether the displayed window may become the tile's matching identity.
  ///
  /// Only a settled, single-window tile adopts it. During a launch burst the
  /// origin gathers several windows and the displayed one is transient;
  /// adopting it then would overwrite the tile's stored title before the
  /// redistribution could match windows against it. A multi-window tile is
  /// likewise still dispatching.
  bool get _canAdoptDisplayedIdentity =>
      !_launchOrigin && _metaWindowSubscriptions.length == 1;

  /// Mirrors the displayed native window's identity into the tile's matching
  /// info, so ownership decisions — and the next burst — match against the
  /// title the tile actually shows.
  ///
  /// The tile's own desktop-entry `appId` and the gather `waitingForAppSince`
  /// are preserved: a tile keeps its application identity and, while it is
  /// empty, the identity of the last window it displayed (so a relaunch finds
  /// it again).
  void _syncMatchingInfo(MetaWindow metaWindow) {
    _matchingInfo = _matchingInfo.copyWith(
      title: metaWindow.title,
      windowClass: metaWindow.windowClass,
      startupId: metaWindow.startupId,
      pid: metaWindow.pid,
    );
  }

  /// Ends the launch gather and decides ownership by title.
  ///
  /// Runs once the burst has settled, when titles are final: the origin
  /// redistributes what it gathered, then reopens a window for itself if it
  /// lost everything it had received. A launch that produced no window is left
  /// alone.
  void _finalizeLaunchBurst() {
    if (!_launchOrigin) {
      return;
    }

    // Titles have settled: matching is by identity from here on.
    _matchingInfo = _matchingInfo.copyWith(waitingForAppSince: null);
    // Clear the origin before redistributing so a throw cannot leave the tile
    // gathering forever; the reopen branch below re-arms it when needed.
    _launchOrigin = false;
    _redistributeOwnedMetaWindows();
    recordMatchingDecision(
      ref,
      () => MatchingDecision.burst(
        windowId: windowIdKey(state.windowId),
        phase: 'settled',
      ),
    );

    final lostEverything = _metaWindowSubscriptions.isEmpty;

    if (lostEverything &&
        _everOwnedWindow &&
        _reopenAttempts < _maxLaunchReopenAttempts) {
      _reopenAttempts++;
      _launchOrigin = true;
      _everOwnedWindow = false;
      matchingLog.info(
        'Launched tile ${state.windowId} lost all its windows to '
        'better-matching siblings; reopening one',
      );
      recordMatchingDecision(
        ref,
        () => MatchingDecision.burst(
          windowId: windowIdKey(state.windowId),
          phase: 'reopened',
        ),
      );
      unawaited(launchSelf());
      return;
    }
    _everOwnedWindow = false;
  }

  /// Redistributes the native windows this tile owns so each lands on its best
  /// home.
  ///
  /// Ownership is decided by identity, principally the title: a sibling that
  /// matches a window better (strictly lower cost) wins it, strongest match
  /// first, destinations deduped. A window left without a better home spreads
  /// to an empty same-app sibling; only when no sibling is free does a leftover
  /// become a dialog of this tile. The displayed window is included — no tile,
  /// launched or not, keeps a window it does not fit.
  void _redistributeOwnedMetaWindows() {
    final owned = _metaWindowSubscriptions.keys.toList()..sort();
    if (owned.isEmpty) {
      return;
    }

    final taken = <WindowId>{state.windowId};
    _recomputeDisplayedMetaWindow();

    // 1. Move each window to a strictly better sibling, recomputing the best
    //    available destination after every move so a taken one falls through to
    //    the next best.
    final remaining = owned.toSet();
    while (remaining.isNotEmpty) {
      final plans = <(MetaWindowId, WindowId, MatchingCost)>[];
      for (final metaWindowId in remaining) {
        final (other, otherCost) = ref
            .read(matchingEngineProvider.notifier)
            .findBestOrdinarySiblingFor(
              metaWindowId,
              excludedWindowIds: taken.toList(),
            );
        if (other == null || otherCost == null) {
          continue;
        }
        final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
        final ownerCost = windowMatchingCost(
          MatchingInfo.fromMetaWindow(metaWindow),
          getMatchingInfo(),
          state,
        );
        if (otherCost.total < ownerCost.total) {
          plans.add((metaWindowId, other, otherCost));
        }
      }
      if (plans.isEmpty) {
        break;
      }
      plans.sort((a, b) {
        final byCost = a.$3.total.compareTo(b.$3.total);
        return byCost != 0 ? byCost : a.$1.compareTo(b.$1);
      });
      var movedAny = false;
      for (final plan in plans) {
        if (taken.contains(plan.$2)) {
          continue;
        }
        _moveMetaWindow(plan.$1, plan.$2, reason: 'sibling', cost: plan.$3);
        taken.add(plan.$2);
        remaining.remove(plan.$1);
        movedAny = true;
      }
      if (!movedAny) {
        break;
      }
    }

    _recomputeDisplayedMetaWindow();

    // 2. A leftover spreads to an empty same-app sibling; when none is free it
    //    has no home and becomes a dialog.
    final leftovers = _metaWindowSubscriptions.keys
        .where((metaWindowId) => metaWindowId != _displayedMetaWindowId)
        .toList()
      ..sort();
    for (final metaWindowId in leftovers) {
      final appId =
          ref.read(metaWindowStateProvider(metaWindowId)).appId ?? '';
      final emptySibling = ref
          .read(matchingEngineProvider.notifier)
          .findEmptySiblingForApp(appId, excludedWindowIds: taken.toList());
      if (emptySibling != null) {
        _moveMetaWindow(metaWindowId, emptySibling, reason: 'emptySibling');
        taken.add(emptySibling);
      } else {
        _makeDialog(metaWindowId);
      }
    }
  }

  void _moveMetaWindow(
    MetaWindowId metaWindowId,
    WindowId destination, {
    required String reason,
    MatchingCost? cost,
  }) {
    recordMatchingDecision(
      ref,
      () => MatchingDecision.move(
        windowId: windowIdKey(state.windowId),
        metaWindowId: metaWindowId,
        toWindowId: windowIdKey(destination),
        reason: reason,
        cost: cost?.toJson(),
      ),
    );
    removeMetaWindow(metaWindowId, shouldNotify: false);
    switch (destination) {
      case PersistentWindowId():
        ref
            .read(persistentWindowStateProvider(destination).notifier)
            .addMetaWindow(metaWindowId);
      case EphemeralWindowId():
        ref
            .read(ephemeralWindowStateProvider(destination).notifier)
            .addMetaWindow(metaWindowId);
      case _: // ignore: no_default_cases
    }
  }

  void _makeDialog(MetaWindowId metaWindowId) {
    print('Creating new dialog window for metaWindow $metaWindowId');
    recordMatchingDecision(
      ref,
      () => MatchingDecision.dialog(
        windowId: windowIdKey(state.windowId),
        metaWindowId: metaWindowId,
      ),
    );
    removeMetaWindow(metaWindowId, shouldNotify: false);
    ref
        .read(windowManagerProvider.notifier)
        .createDialogWindowForMetaWindow(metaWindowId, state.windowId);
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
  /// persisted representation) and into the tile's matching info, so a title
  /// that changes while displayed also updates ownership.
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
            previous.parent != next.parent ||
            previous.activatedBy != next.activatedBy) {
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
      matchingLog.info(
        'Cannot launch tile ${state.windowId}: appId '
        '"${state.properties.appId}" does not resolve to a desktop entry',
      );
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

  /// Whether this tile is the origin of an in-flight launch burst, i.e. still
  /// gathering the windows the launch produced. While it is true, relations
  /// (`activatedBy`, provenance, process sibling) stay owner hints and must not
  /// turn a sibling window into a dialog; the burst needs to gather and
  /// redistribute first. Cleared at the burst settle
  /// ([_finalizeLaunchBurst]).
  bool get isGatheringLaunch => _launchOrigin;

  void waitForSurface(int? pid) {
    _matchingInfo = _matchingInfo.copyWith(
      waitingForAppSince: DateTime.now(),
      pid: pid,
    );
    // A fresh user launch resets the burst state; an internal reopen (see
    // [_finalizeLaunchBurst]) keeps it so the reopen cannot loop.
    if (!_launchOrigin) {
      _everOwnedWindow = false;
      _reopenAttempts = 0;
    }
    _launchOrigin = true;
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
    _debouncedTimer?.cancel();
    _debouncedTimer = null;
  }

  void closeWindow() {
    for (final metaWindowId in _metaWindowSubscriptions.keys) {
      ref.read(metaWindowStateProvider(metaWindowId).notifier).requestToClose();
    }
  }

  void removeWindow();
}
