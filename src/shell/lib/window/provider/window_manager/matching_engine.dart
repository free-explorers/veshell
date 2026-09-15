import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/dev_tools/provider/matching_logs.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
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
  final ISet<MetaWindowId> _surfaceToMatchSet = ISet<MetaWindowId>();
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

  /// Routine to match surfaces to windows.
  /*  void checkMatching() {
    if (_surfaceToMatchSet.isEmpty) {
      return;
    }

    // Purge all surfaces that have been matched for too long.
    for (final surfaceId in _surfaceToMatchSet) {
      final windowId = ref.read(surfaceWindowMapProvider).get(surfaceId);
      if (windowId != null) {
        final matchedAtTime = _getWindowMatchingInfo(windowId).matchedAtTime!;
        if (DateTime.now().difference(matchedAtTime).inMilliseconds >
            MAX_WINDOW_REASSOCIATION_TIME_MS) {
          ref.read(matchingLogsProvider.notifier).print(
                'Remove $surfaceId, it has been matched for suffisent time',
              );
          removeSurface(surfaceId);
        }
      }
    }

    // Filter the list of windows to find matching candidates
    // We only consider Ephemeral or Persistent Windows
    // that have no surfaceId or has been matched recently enough.
    final candidateWindowSet =
        ref.read(windowManagerProvider).where((windowId) {
      if (windowId is DialogWindowId) return false;

      final windowState = _getWindowState(windowId);
      final matchingInfo = _getWindowMatchingInfo(windowId);

      return windowState.surfaceId == null ||
          DateTime.now()
                  .difference(matchingInfo.matchedAtTime!)
                  .inMilliseconds <
              MAX_WINDOW_REASSOCIATION_TIME_MS;
    });

    // group surfaceToMatches by appId
    final surfacesToMatch = <String, List<SurfaceId>>{};
    for (final surfaceId in _surfaceToMatchSet) {
      final appId = ref.read(windowPropertiesStateProvider(surfaceId)).appId;
      surfacesToMatch[appId] ??= [];
      surfacesToMatch[appId]!.add(surfaceId);
    }

    // iterate over entries
    for (final MapEntry(key: appId, value: surfaceIdList)
        in surfacesToMatch.entries) {
      final candidateWindowSetForAppId = candidateWindowSet.where((windowId) {
        final windowState = _getWindowState(windowId);
        return windowState.properties.appId == appId;
      });
      ref.read(matchingLogsProvider.notifier).print(
            'start assignating surface of $appId, surfaceIdList $surfaceIdList, windowCandidates $candidateWindowSetForAppId',
          );

      final costMatrix = <List<int>>[];
      for (final surfaceId in surfaceIdList) {
        final surfaceWindowProperties =
            ref.read(windowPropertiesStateProvider(surfaceId));
        final surfaceMatchInfo =
            MatchingInfo.fromWindowProperties(surfaceWindowProperties);
        final costs = candidateWindowSetForAppId.map((windowId) {
          return windowMatchingCost(
            surfaceMatchInfo,
            _getWindowMatchingInfo(windowId),
            surfaceId,
            _getWindowState(windowId),
          );
        }).toList();

        // Add N items representing potential new windows at the end.
        // In case there are no existing MsWindows, we want to be able to create new ones
        for (var i = 0; i < surfaceIdList.length; i++) {
          costs.add(INF_COST - 1);
        }
        costMatrix.add(costs);
      }

      ref.read(matchingLogsProvider.notifier).print('CostMatrix $costMatrix');

      final WeightedMatchingResult(cost: _, assignments: assignments) =
          weightedMatching(costMatrix);

      ref.read(matchingLogsProvider.notifier).print('Assignments $assignments');

      // The meta window to be assigned to each MsWindow
      final windowAssignments =
          List<SurfaceId?>.filled(candidateWindowSet.length, null);
      for (var i = 0; i < assignments.length; i++) {
        final idx = assignments[i];
        if (idx < candidateWindowSetForAppId.length) {
          // Found a good match
          windowAssignments[idx] = surfaceIdList[i];
        }
      }

      for (var i = 0; i < candidateWindowSet.length; i++) {
        final windowId = candidateWindowSet.elementAt(i);
        final windowState = _getWindowState(windowId);
        if (windowState.surfaceId != null &&
            windowState.surfaceId != windowAssignments[i]) {
          // The contents of this PersistentWindow will be replaced.
          // This can happen if an application starts and opens multiple windows at the same time.
          // Initially, these windows might be associated incorrectly, but once the titles get updated,
          // we can associate them more accurately. This might necessitate swapping some already associated PersistentWindows.
          // For all PersistentWindows which will need to be changed, we first unassign their surfaces.
          ref
              .read(matchingLogsProvider.notifier)
              .print('UnsetSurface of $windowId');
          switch (windowId) {
            case PersistentWindowId():
              ref
                  .read(persistentWindowStateProvider(windowId).notifier)
                  .removeSurface(windowState.surfaceId!);
            case EphemeralWindowId():
              ref
                  .read(ephemeralWindowStateProvider(windowId).notifier)
                  .removeSurface(windowState.surfaceId!);
            case _: // ignore: no_default_cases
          }
        }
      }

      for (var i = 0; i < assignments.length; i++) {
        final idx = assignments[i];
        if (idx < candidateWindowSetForAppId.length) {
          // Found a good match
          final windowId = candidateWindowSetForAppId.elementAt(idx);
          final windowState = _getWindowState(windowId);
          // If the window still have a surface associated, that means the persistent window was already associated correctly
          // and we can skip associating it again.
          if (windowState.surfaceId == null) {
            ref.read(matchingLogsProvider.notifier).print(
                  'Associating ${surfaceIdList[i]} with $windowId',
                );
            // Associate the surface with the persistent window.
            // This promise is designed to run asynchronously and will cancel itself automatically if necessary.
            switch (windowId) {
              case PersistentWindowId():
                ref
                    .read(persistentWindowStateProvider(windowId).notifier)
                    .addSurface(surfaceIdList[i]);
              case EphemeralWindowId():
                ref
                    .read(ephemeralWindowStateProvider(windowId).notifier)
                    .addSurface(surfaceIdList[i]);
              case _: // ignore: no_default_cases
            }
          } else {
            ref.read(matchingLogsProvider.notifier).print(
                  'Skip associating ${surfaceIdList[i]} with $windowId as it is already associated with ${windowState.surfaceId}',
                );
          }
        } else {
          ref.read(matchingLogsProvider.notifier).print(
                'Creating a PersistentWindow for ${surfaceIdList[i]}',
              );
          // Did not find a good match, create a new persistent window instead
          ref
              .read(windowManagerProvider.notifier)
              .createPersistentWindowForSurface(
                surfaceId: surfaceIdList[i],
              );
        }
      }
    }
  } */

  /// Picks the persistent window that should own a newly mapped native
  /// window.
  ///
  /// The decision is split in two orthogonal steps, in this order:
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
  ///   matches by app id: the loader-side dispatch of
  ///   [WindowProviderMixin._dispatchExtraMetaWindows] (not this method)
  ///   sends the overflow to the other placeholder.
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
        return (trackedWindowId, 0);
      }
      return (null, null);
    }
    final costs = candidateWindowSet.map((windowId) {
      return windowMatchingCost(
        metaWindowMatchInfo,
        _getWindowMatchingInfo(windowId),
        _getWindowState(windowId),
      );
    }).toList();

    // Find the index of the minimum cost
    final minCostIndex = costs.indexOf(costs.reduce((a, b) => a < b ? a : b));

    // Return the candidate window with the least cost
    return (candidateWindowSet.elementAt(minCostIndex), costs[minCostIndex]);
  }

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
  }) {
    final appLaunch = ref.read(appLaunchProvider.notifier);
    final cgroupPath = appLaunch.cgroupPathForPid(metaWindow.pid);
    final trackedWindowId = appLaunch.windowForPid(metaWindow.pid);
    if (trackedWindowId == null) {
      matchingLog.info(
        'Provenance unavailable for ${metaWindow.id} '
        'pid=${metaWindow.pid} app_id="${metaWindow.appId}" '
        'cgroup=${cgroupPath ?? 'unknown'}',
      );
      return null;
    }
    if (excludedWindowIds.contains(trackedWindowId)) {
      matchingLog.info(
        'Provenance owner $trackedWindowId excluded for ${metaWindow.id} '
        'pid=${metaWindow.pid} app_id="${metaWindow.appId}"',
      );
      return null;
    }
    if (!ref
        .read(windowsAvailableForMatchingProvider)
        .contains(trackedWindowId)) {
      matchingLog.info(
        'Provenance owner $trackedWindowId not available for matching '
        '(meta window ${metaWindow.id} app_id="${metaWindow.appId}")',
      );
      return null;
    }

    if (_isUnrelatedApplication(metaWindow, trackedWindowId)) {
      matchingLog.info(
        'Provenance rejected: ${metaWindow.id} app_id="${metaWindow.appId}" '
        'identified as unrelated to launch $trackedWindowId',
      );
      return null;
    }

    matchingLog.info(
      'Provenance recovered ${metaWindow.id} '
      'pid=${metaWindow.pid} app_id="${metaWindow.appId}" '
      '→ $trackedWindowId',
    );
    return trackedWindowId;
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
    final (leastCostCandidate, cost) = findBestWindowCandidateForMetaWindow(
      metaWindowId,
    );

    print(leastCostCandidate);
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
