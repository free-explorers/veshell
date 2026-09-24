import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/dev_tools/provider/matching_logs.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/meta_window/provider/process_info_state.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/matching_decision.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_decision_recorder.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_manager/windows_available_for_matching.dart';

part 'matching_engine.g.dart';

/// MatchingEngine attributes freshly mapped native windows
/// ([MetaWindowId]) to shell-side [Window] containers
/// ([PersistentWindowId], [DialogWindowId], [EphemeralWindowId]).
///
/// Vocabulary used across this file and the matching utilities:
///
/// - **MetaWindow**: the shell's mirror of one native Wayland/X11 window.
///   Short-lived, mirrors compositor events, reports properties (app id,
///   title, class, pid...) used for matching.
/// - **Window / PersistentWindow**: the shell's own tile abstraction that
///   survives across sessions. It has its own identity (the desktop entry
///   `appId`), an app id that is *preserved* even when the displayed native
///   window reports a different one, and a display mode.
///
/// The engine is deliberately side-channel free: all inputs (users'
/// available windows, properties, provenance) come from providers so the
/// same rules run for the first mapping, for re-dispatch after a change and
/// for the recovery of tracked launches. Observability of the provenance
/// path goes through `matchingLog` ('Matching'), the ordinary matcher is
/// intentionally not logged to keep the baseline signal-free.
@riverpod
class MatchingEngine extends _$MatchingEngine {
  @override
  IMap<MetaWindowId, WindowId> build() {
    return IMap();
  }

  Window _getWindowState(WindowId windowId) => switch (windowId) {
    EphemeralWindowId() => ref.read(ephemeralWindowStateProvider(windowId)),
    PersistentWindowId() => ref.read(persistentWindowStateProvider(windowId)),
    DialogWindowId() => ref.read(dialogWindowStateProvider(windowId)),
  };

  MatchingInfo _getWindowMatchingInfo(WindowId windowId) => switch (windowId) {
    EphemeralWindowId() =>
      ref
          .read(ephemeralWindowStateProvider(windowId).notifier)
          .getMatchingInfo(),
    PersistentWindowId() =>
      ref
          .read(persistentWindowStateProvider(windowId).notifier)
          .getMatchingInfo(),
    DialogWindowId() => throw Exception("Dialog don't have matching infos"),
  };

  /// Picks the persistent window that should own a newly mapped native
  /// window.
  ///
  /// The decision is split in three orthogonal steps, in this order:
  ///
  /// 1. **Ordinary matching (baseline).** Candidates are the windows visible
  ///    on an active workspace whose persistent `appId` equals the native
  ///    window's reported app id (exact string match, with the empty string
  ///    matching empty). Among them, `windowMatchingCost` ranks identity
  ///    promises (title, class, startup id, pid, waiting-for-launch).
  ///
  /// 2. **Provenance recovery (tracked launch only).** Consulted only when
  ///    step 1 found *nothing* — never to compete with a baseline result. It
  ///    exists because applications report helper identities that resolve to
  ///    no desktop entry and would therefore create a dead-end new window.
  ///
  /// 3. **Process-sibling recovery.** Also consulted only when step 1 found
  ///    *nothing* and step 2 is unavailable (the application was not launched
  ///    through the tracked launcher). It groups a helper-identified native
  ///    window with a window of the same process (same pid or per-application
  ///    cgroup). See [_sameProcessSiblingFor].
  ///
  /// Worked examples:
  ///
  /// - Steam (tracked) spawns `steamwebhelper` surfaces ("Sign in", main
  ///   window, "Special Offers"). Reported `steamwebhelper` resolves to no
  ///   desktop entry → no ordinary candidate ; provenance points at the
  ///   Steam placeholder since the helper inherits the launch cgroup → the
  ///   Steam placeholder is recovered ✓ (this is the case that motivated
  ///   tracked launches).
  /// - Steam (tracked) launches Godot from within Steam. Its app id does not
  ///   resolve either, so it too recovers into the Steam placeholder, where
  ///   the owner's dispatch then presents it as a *dialog* (extra surface of
  ///   an application that already displays a surface).
  /// - Game with its own desktop file launched by Steam: reported id resolves
  ///   to a *different* entry than `steam` → provenance rejected → new
  ///   persistent window, exactly like an untracked launch.
  /// - Code OSS restores two windows at once and only one placeholder
  ///   matches by app id: the tile-side redistributor (not this method) sends
  ///   the overflow to the other placeholder.
  ///
  /// Returns the destination, or `(null, null)` when the caller should
  /// create a new window for the meta window. `excludedWindowIds` removes
  /// candidates (used by the dispatch loop to not send a surface back to the
  /// window it came from, and to avoid double-assigning in one batch).
  (WindowId?, int?) findBestWindowCandidateForMetaWindow(
    MetaWindowId metaWindowId, {
    List<WindowId> excludedWindowIds = const [],
  }) {
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));

    final metaWindowMatchInfo = MatchingInfo.fromMetaWindow(metaWindow);

    final candidateWindowSet = ref
        .read(windowsAvailableForMatchingProvider)
        .where((windowId) {
          if (excludedWindowIds.contains(windowId)) return false;
          final windowState = _getWindowState(windowId);
          return windowState.properties.appId == metaWindowMatchInfo.appId;
        });

    if (candidateWindowSet.isEmpty) {
      // Provenance can only recover a match when ordinary matching found no
      // candidate at all. It never competes with the baseline matcher.
      final trackedWindowId = _trackedLaunchOwnerFor(
        metaWindow,
        excludedWindowIds: excludedWindowIds,
      );
      if (trackedWindowId != null) {
        // Cost 0 marks recovered matches as strong, and keeps them winning
        // the dispatch ordering against ordinary candidates of the same
        // batch.
        recordMatchingDecision(
          ref,
          () => MatchingDecision.fallback(
            metaWindowId: metaWindow.id,
            appId: metaWindowMatchInfo.appId,
            pid: metaWindow.pid,
            cgroup: _cgroupFor(metaWindow),
            outcome: 'provenance',
            trackedWindowId: windowIdKey(trackedWindowId),
          ),
        );
        return (trackedWindowId, 0);
      }

      // Same-process recovery: applications report hollow helper identities
      // (`electron`, runtime names) on windows that actually belong to a
      // process whose other window is already owned. This covers sessions
      // where the application was not started by the tracked launcher (or was
      // already running across a shell restart), for which cgroup provenance
      // is unavailable. Consulted only after the tracked-launch owner, so a
      // real launch attribution always wins.
      final siblingWindowId = _sameProcessSiblingFor(
        metaWindow,
        excludedWindowIds: excludedWindowIds,
      );
      if (siblingWindowId != null) {
        recordMatchingDecision(
          ref,
          () => MatchingDecision.fallback(
            metaWindowId: metaWindow.id,
            appId: metaWindowMatchInfo.appId,
            pid: metaWindow.pid,
            cgroup: _cgroupFor(metaWindow),
            outcome: 'processSibling',
            siblingWindowId: windowIdKey(siblingWindowId),
          ),
        );
        return (siblingWindowId, 0);
      }

      matchingLog.info(
        'No candidate for ${metaWindow.id} app_id="${metaWindow.appId}" '
        'pid=${metaWindow.pid} cgroup=${_cgroupFor(metaWindow) ?? 'unknown'} '
        '→ creating a new window '
        '(no app-id candidate, no tracked provenance, no process sibling)',
      );
      recordMatchingDecision(
        ref,
        () => MatchingDecision.fallback(
          metaWindowId: metaWindow.id,
          appId: metaWindowMatchInfo.appId,
          pid: metaWindow.pid,
          cgroup: _cgroupFor(metaWindow),
          outcome: 'newWindow',
        ),
      );
      return (null, null);
    }
    final candidates = candidateWindowSet.toList();
    final costs = [
      for (final windowId in candidates)
        windowMatchingCost(
          metaWindowMatchInfo,
          _getWindowMatchingInfo(windowId),
          _getWindowState(windowId),
        ),
    ];

    // Pick the least cost. The burst mapping order is not stable, so ties are
    // broken on a fixed key instead of relying on iteration order: two
    // candidates only tie when every signal is identical, and the choice must
    // still be reproducible.
    var bestIndex = 0;
    for (var i = 1; i < candidates.length; i++) {
      final betterCost = costs[i].total < costs[bestIndex].total;
      final tiedButStable =
          costs[i].total == costs[bestIndex].total &&
          _stableWindowKey(candidates[i]).compareTo(
                _stableWindowKey(candidates[bestIndex]),
              ) <
              0;
      if (betterCost || tiedButStable) {
        bestIndex = i;
      }
    }

    final bestCost = costs[bestIndex].total;
    recordMatchingDecision(
      ref,
      () => MatchingDecision.candidates(
        metaWindowId: metaWindow.id,
        appId: metaWindowMatchInfo.appId,
        pid: metaWindow.pid,
        excludedWindowIds: [
          for (final windowId in excludedWindowIds) windowIdKey(windowId),
        ],
        candidates: [
          for (var i = 0; i < candidates.length; i++)
            {
              'windowId': windowIdKey(candidates[i]),
              'appId': _getWindowState(candidates[i]).properties.appId,
              'title': _getWindowMatchingInfo(candidates[i]).title,
              'windowClass': _getWindowMatchingInfo(candidates[i]).windowClass,
              'cost': costs[i].toJson(),
            },
        ],
        chosenWindowId: windowIdKey(candidates[bestIndex]),
        chosenCost: bestCost,
        tieBreak: costs.where((c) => c.total == bestCost).length > 1,
      ),
    );

    return (candidates[bestIndex], bestCost);
  }

  /// Deterministic ordering key used only to break exact ties between
  /// candidates. It never overrides a better match.
  String _stableWindowKey(WindowId windowId) => switch (windowId) {
        PersistentWindowId() => 'p:${windowId.uuid}',
        EphemeralWindowId() => 'e:${windowId.uuid}',
        DialogWindowId() => 'd:${windowId.uuid}',
      };

  /// Best sibling for [metaWindowId] by **ordinary** app-id matching only.
  ///
  /// Deliberately excludes provenance and process-sibling recovery, which are
  /// resolved once at mapping time. Recovery is symmetric (two same-process
  /// windows point at each other), so letting it drive the redistribution move
  /// decisions would make them oscillate; the redistribution compares identity
  /// cost only, and a strictly lower cost wins.
  (WindowId?, MatchingCost?) findBestOrdinarySiblingFor(
    MetaWindowId metaWindowId, {
    List<WindowId> excludedWindowIds = const [],
  }) {
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
    final metaWindowMatchInfo = MatchingInfo.fromMetaWindow(metaWindow);
    final candidates = ref
        .read(windowsAvailableForMatchingProvider)
        .where((windowId) {
      if (excludedWindowIds.contains(windowId)) return false;
      if (windowId is DialogWindowId) return false;
      return _getWindowState(windowId).properties.appId ==
          metaWindowMatchInfo.appId;
    }).toList();
    if (candidates.isEmpty) {
      return (null, null);
    }
    final costs = [
      for (final windowId in candidates)
        windowMatchingCost(
          metaWindowMatchInfo,
          _getWindowMatchingInfo(windowId),
          _getWindowState(windowId),
        ),
    ];
    var bestIndex = 0;
    for (var i = 1; i < candidates.length; i++) {
      final better = costs[i].total < costs[bestIndex].total;
      final tiedButStable =
          costs[i].total == costs[bestIndex].total &&
          _stableWindowKey(candidates[i]).compareTo(
                _stableWindowKey(candidates[bestIndex]),
              ) <
              0;
      if (better || tiedButStable) {
        bestIndex = i;
      }
    }
    return (candidates[bestIndex], costs[bestIndex]);
  }

  /// The first same-app tile that owns no native window, in the stable
  /// candidate order. Used to spread leftover windows over empty placeholders
  /// instead of turning them into dialogs.
  WindowId? findEmptySiblingForApp(
    String appId, {
    List<WindowId> excludedWindowIds = const [],
  }) {
    if (appId.isEmpty) {
      return null;
    }
    for (final windowId in ref.read(windowsAvailableForMatchingProvider)) {
      if (excludedWindowIds.contains(windowId)) continue;
      if (windowId is DialogWindowId) continue;
      final state = _getWindowState(windowId);
      if (state.properties.appId != appId) continue;
      if (state.metaWindowId == null) {
        return windowId;
      }
    }
    return null;
  }

  /// Resolves the top-level tile that ultimately owns [windowId].
  ///
  /// Dialogs can chain (a dialog opened from a dialog), but a native window
  /// must always attach to the tile at the root of the chain: a dialog is
  /// never nested under another dialog.
  WindowId rootTileFor(WindowId windowId) {
    var current = windowId;
    for (var guard = 0; guard < 32 && current is DialogWindowId; guard++) {
      try {
        current = ref.read(dialogWindowStateProvider(current)).parentWindowId;
      } on Object {
        break;
      }
    }
    return current;
  }

  /// The tile that should own a dialog-like window, using the explicit
  /// relations only: client parent, activation "opened from", tracked-launch
  /// provenance, then process sibling. Returns null when nothing authoritative
  /// is known, so a weak hint (a lone fixed size) never turns a regular window
  /// into a dialog. [log] is forwarded to the recovery lookups; it is turned
  /// off on the ordinary matching path so a plain new window does not emit
  /// provenance diagnostics.
  WindowId? dialogOwnerFromRelation(
    MetaWindowId metaWindowId, {
    bool log = true,
  }) {
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
    final parentId = metaWindow.parent;
    if (parentId != null) {
      final parentTile = ref.read(metaWindowWindowMapProvider).get(parentId);
      if (parentTile != null) {
        return rootTileFor(parentTile);
      }
    }
    final activatedById = metaWindow.activatedBy;
    if (activatedById != null) {
      final activatedByTile = ref
          .read(metaWindowWindowMapProvider)
          .get(activatedById);
      if (activatedByTile != null) {
        return rootTileFor(activatedByTile);
      }
    }
    final tracked = _trackedLaunchOwnerFor(
      metaWindow,
      excludedWindowIds: const [],
      log: log,
    );
    if (tracked != null) {
      return tracked;
    }
    return _sameProcessSiblingFor(
      metaWindow,
      excludedWindowIds: const [],
      log: log,
    );
  }

  /// The tile that should own a dialog-like window, falling back to the
  /// ordinary best candidate when no explicit relation exists.
  WindowId? resolveDialogOwnerIfAny(MetaWindowId metaWindowId) {
    final relation = dialogOwnerFromRelation(metaWindowId);
    if (relation != null) {
      return relation;
    }
    return findBestWindowCandidateForMetaWindow(metaWindowId).$1;
  }

  /// Whether the launch burst that produced [metaWindowId] is still gathering,
  /// so the window must go through ordinary matching instead of attaching as a
  /// dialog of the window it was opened from.
  ///
  /// This is the temporal half of the burst-vs-further-opening distinction.
  /// The primary signal is a tile of the same application currently gathering a
  /// launch (waiting bonus armed): while it is armed the burst must collect and
  /// redistribute, and the clicked tile's waiting bonus already wins the
  /// ordinary match. Relations recorded on the window (`activatedBy`,
  /// provenance, process sibling) are then only owner hints — the lookups are
  /// deliberately silent, unlike [_trackedLaunchOwnerFor] and
  /// [_sameProcessSiblingFor], so the ordinary matching path stays free of
  /// recovery logging.
  bool isLaunchBurstInProgressFor(MetaWindowId metaWindowId) {
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));
    final metaAppId = MatchingInfo.fromMetaWindow(metaWindow).appId;

    // A clicked placeholder may be gathering a launch for an application whose
    // already-running process keeps no provenance (single-instance apps re-home
    // into `app-*.scope`) and opens windows attributed to the first launch's
    // tile. While a placeholder of this app is gathering, route through
    // ordinary matching so the window lands on the clicked tile — its waiting
    // bonus wins — instead of becoming a dialog of the already-assigned one.
    for (final windowId in ref.read(windowManagerProvider).windows) {
      if (windowId is DialogWindowId) continue;
      if (!_isGatheringLaunch(windowId)) continue;
      if (_getWindowState(windowId).properties.appId == metaAppId) {
        return true;
      }
    }

    // The tile that launched the window's process. Covers single-instance
    // relaunches, where the window is created by the already-running instance
    // (keeping the first launch's cgroup) and the activation relation may
    // point at another window.
    final launchingTile = ref
        .read(appLaunchProvider.notifier)
        .windowForPid(metaWindow.pid);
    if (launchingTile != null && _isGatheringLaunch(launchingTile)) {
      return true;
    }

    // The window this one was opened from (activation or client parent).
    for (final ancestor in [metaWindow.activatedBy, metaWindow.parent]) {
      if (ancestor == null) continue;
      final ancestorTile = ref.read(metaWindowWindowMapProvider).get(ancestor);
      if (ancestorTile != null && _isGatheringLaunch(ancestorTile)) {
        return true;
      }
    }

    // Process-sibling fallback for launches without tracked provenance (no
    // systemd user manager): the burst window shares the pid or the
    // per-application cgroup with an already-gathered window.
    final cgroupPath = _cgroupFor(metaWindow);
    for (final entry in ref.read(metaWindowWindowMapProvider).entries) {
      if (entry.key == metaWindow.id) continue;
      final siblingTile = entry.value;
      if (siblingTile is DialogWindowId) continue;
      if (!_isGatheringLaunch(siblingTile)) continue;
      final sibling = ref.read(metaWindowStateProvider(entry.key));
      final samePid = sibling.pid != 0 && sibling.pid == metaWindow.pid;
      final sameCgroup =
          !samePid &&
          cgroupPath != null &&
          _isPerAppScope(cgroupPath) &&
          cgroupPath == _cgroupFor(sibling);
      if (samePid || sameCgroup) {
        return true;
      }
    }

    return false;
  }

  /// Whether [windowId] is a tile currently gathering a launch burst.
  bool _isGatheringLaunch(WindowId windowId) => switch (windowId) {
        EphemeralWindowId() => ref
            .read(ephemeralWindowStateProvider(windowId).notifier)
            .isGatheringLaunch,
        PersistentWindowId() => ref
            .read(persistentWindowStateProvider(windowId).notifier)
            .isGatheringLaunch,
        DialogWindowId() => false,
      };

  /// Returns the persistent window owning the tracked launch of the given
  /// native window, if provenance is known and the window is still an eligible
  /// destination.
  ///
  /// How provenance is established: every application launch runs inside a
  /// disposable, uniquely named `veshell-launch-*.service` cgroup whose key
  /// (native window id → placeholder) is kept in [AppLaunch] until the tracked
  /// service exits. A native window belongs to a launch when its process is
  /// still in that cgroup. Descendants keep their parent cgroup, which is
  /// what makes helpers ("steamwebhelper", Electron runtimes, games launched
  /// from Steam) inherit attribution even though they report their own app id.
  ///
  /// A recovered match must not override a clearly identified different
  /// application: if the native window reports an app id that resolves to a
  /// desktop entry unrelated to the launching placeholder (e.g. a game with
  /// its own `game.desktop` launched by Steam), provenance is not trusted and
  /// the caller falls back to its ordinary behavior. See
  /// [_isUnrelatedApplication] for the identity resolution rules.
  ///
  /// Failure reasons are logged under 'Matching' with the resolved cgroup
  /// path, which also makes cgroup-migration issues visible (applications
  /// re-homing into `app-*.scope` are inherently not attributable).
  WindowId? _trackedLaunchOwnerFor(
    MetaWindow metaWindow, {
    required List<WindowId> excludedWindowIds,
    bool log = true,
  }) {
    final appLaunch = ref.read(appLaunchProvider.notifier);
    final cgroupPath = _cgroupFor(metaWindow);
    final trackedWindowId = appLaunch.windowForPid(metaWindow.pid);
    if (trackedWindowId == null) {
      if (log) {
        matchingLog.info(
          'Provenance unavailable for ${metaWindow.id} '
          'pid=${metaWindow.pid} app_id="${metaWindow.appId}" '
          'cgroup=${cgroupPath ?? 'unknown'}',
        );
      }
      return null;
    }
    if (excludedWindowIds.contains(trackedWindowId)) {
      if (log) {
        matchingLog.info(
          'Provenance owner $trackedWindowId excluded for ${metaWindow.id} '
          'pid=${metaWindow.pid} app_id="${metaWindow.appId}"',
        );
      }
      return null;
    }
    if (!ref
        .read(windowsAvailableForMatchingProvider)
        .contains(trackedWindowId)) {
      if (log) {
        matchingLog.info(
          'Provenance owner $trackedWindowId not available for matching '
          '(meta window ${metaWindow.id} app_id="${metaWindow.appId}")',
        );
      }
      return null;
    }

    if (_isUnrelatedApplication(metaWindow, trackedWindowId)) {
      if (log) {
        matchingLog.info(
          'Provenance rejected: ${metaWindow.id} app_id="${metaWindow.appId}" '
          'identified as unrelated to launch $trackedWindowId',
        );
      }
      return null;
    }

    if (log) {
      matchingLog.info(
        'Provenance recovered ${metaWindow.id} '
        'pid=${metaWindow.pid} app_id="${metaWindow.appId}" '
        '→ $trackedWindowId',
      );
    }
    return trackedWindowId;
  }

  /// Returns the shell window already owning a native window from the *same
  /// process* (same pid, or same per-application cgroup when pids differ), if
  /// any.
  ///
  /// Motivation: some applications advertise a hollow helper identity
  /// (`electron`, runtime names) on windows that actually belong to an
  /// application whose other window is already owned — e.g. Code OSS opening
  /// its About window with `app_id="electron"` while the main window reports
  /// `code-oss`. When the application was not launched through the tracked
  /// launcher (already running across a shell restart, or started by another
  /// session), [AppLaunch] has no attribution and the window would otherwise
  /// become a standalone tile.
  ///
  /// Only consulted when ordinary app-id matching found nothing and the
  /// tracked-launch owner is unavailable, so it never overrides a real
  /// identity match. The recovered destination is returned as a strong
  /// (cost 0) match, letting the owner's dispatch group the extra window as a
  /// dialog under its already-displayed sibling — exactly like a helper
  /// window recovered through cgroup provenance.
  ///
  /// Two gates keep the fallback conservative:
  ///
  /// 1. The candidate must share the pid, or a *per-application* cgroup
  ///    (`app-*.scope`). Shared session/wrapper cgroups are ignored because
  ///    they host unrelated applications.
  /// 2. The identity must not resolve to a different desktop entry than the
  ///    sibling tile ([_isUnrelatedApplication]), matching tracked
  ///    provenance.
  ///
  /// Window shape ([MetaWindow.isFixedSized], [MetaWindow.isModal]) is *not*
  /// required: when no persistent window can host the window, grouping it
  /// under its process sibling is preferred over a standalone tile.
  WindowId? _sameProcessSiblingFor(
    MetaWindow metaWindow, {
    required List<WindowId> excludedWindowIds,
    bool log = true,
  }) {
    if (metaWindow.pid == 0) {
      return null;
    }

    final windowMap = ref.read(metaWindowWindowMapProvider);
    if (windowMap.isEmpty) {
      return null;
    }

    final availableForMatching = ref.read(windowsAvailableForMatchingProvider);
    final cgroupPath = _cgroupFor(metaWindow);

    for (final entry in windowMap.entries) {
      final siblingMetaWindowId = entry.key;
      final siblingWindowId = entry.value;
      if (siblingMetaWindowId == metaWindow.id) continue;
      if (excludedWindowIds.contains(siblingWindowId)) continue;
      if (!availableForMatching.contains(siblingWindowId)) continue;

      final siblingMetaWindow = ref.read(
        metaWindowStateProvider(siblingMetaWindowId),
      );
      final samePid =
          siblingMetaWindow.pid != 0 && siblingMetaWindow.pid == metaWindow.pid;
      // A shared cgroup is a weak signal: wrapper scopes (terminals, launcher
      // scripts, `systemd-run` wrappers) host unrelated applications. Only
      // trust it for per-application scopes (`app-*.scope`), which systemd
      // creates one of per launched application.
      final sameCgroup =
          !samePid &&
          cgroupPath != null &&
          _isPerAppScope(cgroupPath) &&
          cgroupPath == _cgroupFor(siblingMetaWindow);

      if (!samePid && !sameCgroup) {
        continue;
      }

      // A shared process/cgroup is not enough: a helper process can also open
      // a window that genuinely belongs to another application. Reject the
      // recovery when the reported identity resolves to a different desktop
      // entry than the sibling tile, mirroring tracked-launch provenance.
      if (_isUnrelatedApplication(metaWindow, siblingWindowId)) {
        if (log) {
          matchingLog.info(
            'Process-sibling rejected: ${metaWindow.id} '
            'app_id="${metaWindow.appId}" identified as unrelated to '
            '$siblingWindowId',
          );
        }
        continue;
      }

      if (log) {
        matchingLog.info(
          'Process-sibling recovered ${metaWindow.id} '
          'pid=${metaWindow.pid} app_id="${metaWindow.appId}" '
          '(cgroup=${cgroupPath ?? 'unknown'}) '
          '→ $siblingWindowId '
          '(same ${samePid ? 'pid' : 'cgroup'} as $siblingMetaWindowId)',
        );
      }
      return siblingWindowId;
    }
    return null;
  }

  /// Whether a unified cgroup path names a per-application systemd scope
  /// (`app-<name>-<pid>.scope`), as opposed to a session/terminal/wrapper
  /// scope that may host several unrelated applications.
  bool _isPerAppScope(String cgroupPath) {
    final basename = cgroupPath.split('/').last;
    return basename.startsWith('app-') && basename.endsWith('.scope');
  }

  /// Unified cgroup path of the process behind a native window, or null when
  /// unknown. Comes from the compositor-provided process facts (refreshed at
  /// creation, on pid change and on map), which keeps the value reachable
  /// after the process exits — unlike a `/proc` read at match time. Exposed as
  /// a single call site so diagnostics and sibling recovery share it.
  String? _cgroupFor(MetaWindow metaWindow) {
    final processInfo = ref.read(processInfoStateProvider.notifier);
    return processInfo.forPid(metaWindow.pid)?.cgroup;
  }

  /// When provenance disagrees with the native window's *own* identity.
  ///
  /// \> Reported app ids are noisy: binaries and runtimes surface names like
  /// \> `steamwebhelper`, `electron` or `Godot_Engine` for windows that actually
  /// \> belong to another application. To avoid those hollow ids defeating the
  /// \> recovery (and, on the other side, avoid forcing an unrelated app into
  /// \> a placeholder), the decision is taken on **desktop-entry identity**:
  ///
  /// 1. Map both the reported id and the launching placeholder's app id to
  ///    desktop entry ids ([localizedDesktopEntriesProvider], with the
  ///    binary-name fallback of `binaryToAppId`, so `brave` ≈ `brave-browser`).
  /// 2. Conflict (return true) only when *both* resolve to known entries and
  ///    those entries differ.
  /// 3. Anything else (empty id, unresolved id, unresolved launch id) is
  ///    treated as a helper/wrapper identity: provenance wins.
  ///
  /// Examples:
  ///
  /// - reported `steamwebhelper`, launch `steam` — unresolved → compatible,
  ///   recovery allowed.
  /// - reported `brave`, launch `brave-browser` — both resolve, same entry →
  ///   related, recovery allowed.
  /// - reported `game-xyz`, launch `steam`, both resolvable and different →
  ///   conflict, provenance rejected (caller creates a fresh window).
  ///
  /// Note the asymmetry: an unresolvable id like `Godot_Engine` launched by
  /// Steam also recovers into the Steam placeholder (then shows as dialog).
  /// That is accepted: without a desktop file there is nothing else to
  /// attribute the window to.
  bool _isUnrelatedApplication(
    MetaWindow metaWindow,
    WindowId trackedWindowId,
  ) {
    final reportedAppId = metaWindow.appId ?? '';
    if (reportedAppId.isEmpty) {
      return false;
    }

    final entries = ref.read(localizedDesktopEntriesProvider).value;
    if (entries == null) {
      // Desktop entries are not loaded yet: identity cannot be compared.
      return false;
    }
    final binaryToAppId = ref.read(binaryToAppIdProvider).value;

    String? resolveDesktopAppId(String appId) {
      final desktopEntryId =
          entries[appId]?.desktopEntry.id ?? binaryToAppId?[appId];
      return desktopEntryId;
    }

    final launchAppId = _getWindowState(trackedWindowId).properties.appId;

    final reportedDesktopAppId = resolveDesktopAppId(reportedAppId);
    if (reportedDesktopAppId == null) {
      return false;
    }

    if (reportedDesktopAppId == launchAppId) {
      return false;
    }

    final launchDesktopAppId = resolveDesktopAppId(launchAppId);
    if (launchDesktopAppId == reportedDesktopAppId) {
      return false;
    }

    matchingLog.info(
      'Identity conflict for window ${metaWindow.id}: '
      'reported app_id="$reportedAppId" resolves to "$reportedDesktopAppId" '
      'but launch app_id="$launchAppId" resolves to "$launchDesktopAppId"',
    );
    return true;
  }

  void matchMetaWindowToBestWindowCandidate(MetaWindowId metaWindowId) {
    final (leastCostCandidate, _) = findBestWindowCandidateForMetaWindow(
      metaWindowId,
    );

    switch (leastCostCandidate) {
      case PersistentWindowId():
        ref
            .read(persistentWindowStateProvider(leastCostCandidate).notifier)
            .addMetaWindow(metaWindowId);
      case EphemeralWindowId():
        ref
            .read(ephemeralWindowStateProvider(leastCostCandidate).notifier)
            .addMetaWindow(metaWindowId);
      case _:
        ref
            .read(windowManagerProvider.notifier)
            .createPersistentWindowForMetaWindow(metaWindowId: metaWindowId);
    }
  }

  /// Add a new Surface to the matching engine.
  void addMetaWindow(MetaWindowId metaWindowId) {
    ref
        .read(matchingLogsProvider.notifier)
        .print('Add MetaWindow $metaWindowId to matching engine');
    matchMetaWindowToBestWindowCandidate(metaWindowId);
  }
}
