import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/surface_window_map.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';
import 'package:shell/window/provider/window_manager/weighted_matching.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_properties.dart';

part 'matching_engine.g.dart';

/// MatchingEngine is responsible for matching surfaces to windows.
@Riverpod(keepAlive: true)
class MatchingEngine extends _$MatchingEngine {
  ISet<SurfaceId> _surfaceToMatchSet = ISet<SurfaceId>();
  @override
  IMap<SurfaceId, WindowId> build() {
    return IMap();
  }

  void checkMatching() {
    if (_surfaceToMatchSet.isEmpty) {
      return;
    }
    print('MATCHING - checkMatching Start');

    // Purge all surfaces that have been matched for too long.
    for (final surfaceId in _surfaceToMatchSet) {
      if (ref.read(surfaceWindowMapProvider).get(surfaceId)
          case final PersistentWindowId windowId) {
        final matchedAtTime = ref
            .read(persistentWindowStateProvider(windowId).notifier)
            .getMatchingInfo()
            .matchedAtTime!;
        if (DateTime.now().difference(matchedAtTime).inMilliseconds >
            MAX_WINDOW_REASSOCIATION_TIME_MS) {
          removeSurface(surfaceId);
        }
      }
    }

    // A PersistentWindow is a candidate for matching if it has no surfaceId
    // or if it has a surfaceId but it has been matched recently enough.
    final candidatePersistentWindowSet = ref
        .read(windowManagerProvider.notifier)
        .getPersistentWindowSet()
        .where((persistentWindowId) {
      final windowState =
          ref.read(persistentWindowStateProvider(persistentWindowId));
      final matchingInfo = ref
          .read(persistentWindowStateProvider(persistentWindowId).notifier)
          .getMatchingInfo();
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
      final candidatePersistentWindowSetForAppId =
          candidatePersistentWindowSet.where((persistentWindowId) {
        final windowState =
            ref.read(persistentWindowStateProvider(persistentWindowId));
        return windowState.properties.appId == appId;
      });
      print(
        'MATCHING - start assignating surface of $appId, surfaceIdList $surfaceIdList, windowCandidates $candidatePersistentWindowSetForAppId ',
      );

      final costMatrix = <List<int>>[];
      for (final surfaceId in surfaceIdList) {
        final surfaceWindowProperties =
            ref.read(windowPropertiesStateProvider(surfaceId));
        final surfaceMatchInfo =
            MatchingInfo.fromWindowProperties(surfaceWindowProperties);
        final costs =
            candidatePersistentWindowSetForAppId.map((persistentWindowId) {
          return windowMatchingCost(
            surfaceMatchInfo,
            ref
                .read(
                  persistentWindowStateProvider(persistentWindowId).notifier,
                )
                .getMatchingInfo(),
            surfaceId,
            ref.read(persistentWindowStateProvider(persistentWindowId)),
          );
        }).toList();

        // Add N items representing potential new windows at the end.
        // In case there are no existing MsWindows, we want to be able to create new ones
        for (var i = 0; i < surfaceIdList.length; i++) {
          costs.add(INF_COST - 1);
        }
        costMatrix.add(costs);
      }

      print('MATCHES - costMatrix $costMatrix');

      final WeightedMatchingResult(cost: _, assignments: assignments) =
          weightedMatching(costMatrix);

      print('MATCHES - assignments $assignments');

      // The meta window to be assigned to each MsWindow
      final windowAssignments =
          List<SurfaceId?>.filled(candidatePersistentWindowSet.length, null);
      for (var i = 0; i < assignments.length; i++) {
        final idx = assignments[i];
        if (idx < candidatePersistentWindowSetForAppId.length) {
          // Found a good match
          windowAssignments[idx] = surfaceIdList[i];
        }
      }

      for (var i = 0; i < candidatePersistentWindowSet.length; i++) {
        final persistentWindowId = candidatePersistentWindowSet.elementAt(i);
        final windowState =
            ref.read(persistentWindowStateProvider(persistentWindowId));
        if (windowState.surfaceId != null &&
            windowState.surfaceId != windowAssignments[i]) {
          // The contents of this PersistentWindow will be replaced.
          // This can happen if an application starts and opens multiple windows at the same time.
          // Initially, these windows might be associated incorrectly, but once the titles get updated,
          // we can associate them more accurately. This might necessitate swapping some already associated PersistentWindows.
          // For all PersistentWindows which will need to be changed, we first unassign their surfaces.
          print('MATCHING - unsetSurface of $persistentWindowId');
          ref
              .read(persistentWindowStateProvider(persistentWindowId).notifier)
              .unsetSurface();
        }
      }

      for (var i = 0; i < assignments.length; i++) {
        final idx = assignments[i];
        if (idx < candidatePersistentWindowSet.length) {
          // Found a good match
          final persistentWindowId =
              candidatePersistentWindowSet.elementAt(idx);
          final windowState =
              ref.read(persistentWindowStateProvider(persistentWindowId));
          // If the window still have a surface associated, that means the persistent window was already associated correctly
          // and we can skip associating it again.
          if (windowState.surfaceId == null) {
            print(
              'MATCHING - Associating $surfaceIdList[i] with $persistentWindowId',
            );
            // Associate the surface with the persistent window.
            // This promise is designed to run asynchronously and will cancel itself automatically if necessary.
            ref
                .read(
                  persistentWindowStateProvider(persistentWindowId).notifier,
                )
                .matchWithSurface(surfaceIdList[i]);
          }
        } else {
          print(
            'MATCHING - Creating a PersistentWindow for $surfaceIdList[i]',
          );
          // Did not find a good match, create a new persistent window instead
          ref
              .read(windowManagerProvider.notifier)
              .createPersistentWindowForSurface(
                surfaceId: surfaceIdList[i],
                appId: appId,
                title: ref
                    .read(windowPropertiesStateProvider(surfaceIdList[i]))
                    .title,
              );
        }
      }
    }
  }

  addSurface(SurfaceId surfaceId) {
    print('MATCHING - Add surface $surfaceId from matching engine');
    _surfaceToMatchSet = _surfaceToMatchSet.add(surfaceId);
    checkMatching();
  }

  removeSurface(SurfaceId surfaceId) {
    print('MATCHING - Remove surface $surfaceId from matching engine');
    if (_surfaceToMatchSet.contains(surfaceId)) {
      _surfaceToMatchSet = _surfaceToMatchSet.remove(surfaceId);
    }
  }
}
