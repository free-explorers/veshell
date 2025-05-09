import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/dev_tools/provider/matching_logs.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

part 'matching_engine.g.dart';

/// MatchingEngine is responsible for matching surfaces to windows.
@Riverpod(keepAlive: true)
class MatchingEngine extends _$MatchingEngine {
  final ISet<MetaWindowId> _surfaceToMatchSet = ISet<MetaWindowId>();
  @override
  IMap<MetaWindowId, WindowId> build() {
    return IMap();
  }

  Window _getWindowState(WindowId windowId) => switch (windowId) {
        EphemeralWindowId() => ref.read(ephemeralWindowStateProvider(windowId)),
        PersistentWindowId() =>
          ref.read(persistentWindowStateProvider(windowId)),
        DialogWindowId() => ref.read(dialogWindowStateProvider(windowId)),
      };

  MatchingInfo _getWindowMatchingInfo(WindowId windowId) => switch (windowId) {
        EphemeralWindowId() => ref
            .read(ephemeralWindowStateProvider(windowId).notifier)
            .getMatchingInfo(),
        PersistentWindowId() => ref
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

  (WindowId?, int?) findBestWindowCandidateForMetaWindow(
    MetaWindowId metaWindowId, {
    List<WindowId> excludedWindowIds = const [],
  }) {
    final metaWindow = ref.read(metaWindowStateProvider(metaWindowId));

    final metaWindowMatchInfo = MatchingInfo.fromMetaWindow(metaWindow);

    final candidateWindowSet =
        ref.read(windowManagerProvider).where((windowId) {
      if (windowId is DialogWindowId) return false;
      if (excludedWindowIds.contains(windowId)) return false;
      final windowState = _getWindowState(windowId);
      return windowState.properties.appId == metaWindowMatchInfo.appId;
    });

    if (candidateWindowSet.isEmpty) {
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

  void matchMetaWindowToBestWindowCandidate(MetaWindowId metaWindowId) {
    final (leastCostCandidate, cost) =
        findBestWindowCandidateForMetaWindow(metaWindowId);

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
            .createPersistentWindowForMetaWindow(
              metaWindowId: metaWindowId,
            );
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
