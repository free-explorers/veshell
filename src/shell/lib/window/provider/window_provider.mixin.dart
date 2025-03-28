import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/surface_window_map.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_properties.dart';

mixin WindowProviderMixin<T extends Window> {
  T get state;
  set state(T value);
  AutoDisposeNotifierProviderRef<T> get ref;
  KeepAliveLink? _keepAliveLink;

  final Map<SurfaceId, ProviderSubscription<WindowProperties>>
      _surfaceSubscriptions = {};

  SurfaceId? _displayedSurfaceId;

  late MatchingInfo _matchingInfo;

  Timer? _debouncedTimer;

  /// Initialized a Window by keeping it alive and setting the surface.
  void initialize(T window) {
    _keepAliveLink?.close();
    _keepAliveLink = ref.keepAlive();
    state = window;
    _matchingInfo = MatchingInfo.fromWindowProperties(
      window.properties,
    );
    if (state.surfaceId != null) {
      addSurface(state.surfaceId!);
    }
  }

  /// Assign a surface to a Window subscribing to any changes
  void addSurface(SurfaceId surfaceId) {
    _matchingInfo = _matchingInfo.copyWith(
      waitingForAppSince: null,
    );
    ref.read(surfaceWindowMapProvider.notifier).set(
          surfaceId,
          state.windowId,
        );
    _listenForSurfaceChanges(surfaceId);
    _onSurfacesChanges();
  }

  /// When surfaces are added, removed or updated
  /// we need to determine which surface should be displayed
  /// and try to find best matches for the other surfaces
  void _onSurfacesChanges() {
    SurfaceId? newDisplayedSurfaceId;
    // Reset the timer if changes occurs while we are waiting

    _debouncedTimer?.cancel();

    if (_surfaceSubscriptions.isNotEmpty) {
      if (_surfaceSubscriptions.length == 1) {
        newDisplayedSurfaceId = _surfaceSubscriptions.keys.first;
      } else {
        // pick the surface with the lest matching cost
        final surfaceIdList = _surfaceSubscriptions.keys.toList();
        final costs = surfaceIdList.map((surfaceId) {
          final surfaceWindowProperties =
              ref.read(windowPropertiesStateProvider(surfaceId));
          final surfaceMatchInfo =
              MatchingInfo.fromWindowProperties(surfaceWindowProperties);
          return windowMatchingCost(
            surfaceMatchInfo,
            getMatchingInfo(),
            surfaceId,
            state,
          );
        }).toList();
        final minCost = costs.reduce(min);
        newDisplayedSurfaceId = surfaceIdList[costs.indexOf(minCost)];
      }

      // after this timer we need to dispatch any extra surfaces
      // to the best matches available or create new windows for them
      _debouncedTimer = Timer(
        const Duration(milliseconds: 100),
        () {
          if (_surfaceSubscriptions.length > 1) {
            _dispatchExtraSurfaces();
          }
        },
      );
    }
    if (newDisplayedSurfaceId != _displayedSurfaceId) {
      _displayedSurfaceId = newDisplayedSurfaceId;
      print('new displayed surface: $_displayedSurfaceId');
      displayedSurfaceChanged(_displayedSurfaceId);
    }
  }

  // For each surface that is not the displayed surface
  // either find a better match or create a new window for it
  void _dispatchExtraSurfaces() {
    final surfacesToDispatch = _surfaceSubscriptions.keys
        .where((surfaceId) => surfaceId != _displayedSurfaceId)
        .toSet();

    final excludedWindowIds = [state.windowId];
    print('Dispatching extra surfaces $surfacesToDispatch');

    while (surfacesToDispatch.isNotEmpty) {
      final bestMatchForSurfaceMap = <SurfaceId, (WindowId?, int?)>{};
      for (final surfaceId in surfacesToDispatch) {
        bestMatchForSurfaceMap[surfaceId] = ref
            .read(matchingEngineProvider.notifier)
            .findBestWindowCandidateForSurface(
              surfaceId,
              excludedWindowIds: excludedWindowIds,
            );
      }

      bestMatchForSurfaceMap.entries
          .sorted(
        (entry1, entry2) =>
            (entry2.value.$2 ?? 0).compareTo(entry1.value.$2 ?? 0),
      )
          .forEach((entry) {
        final surfaceId = entry.key;
        final (windowId, score) = entry.value;

        // If there is no windowId, create a new one
        if (windowId == null) {
          print('Creating new window for surface $surfaceId');
          removeSurface(surfaceId, shouldNotify: false);

          final newWindowId = switch (state.windowId) {
            PersistentWindowId() => ref
                .read(windowManagerProvider.notifier)
                .createPersistentWindowForSurface(
                  surfaceId: surfaceId,
                ),
            EphemeralWindowId() => ref
                .read(windowManagerProvider.notifier)
                .createEphemeralWindowForSurface(
                  surfaceId: surfaceId,
                  screenId: (state as EphemeralWindow).screenId,
                ),
            _ => throw UnimplementedError(),
          };

          excludedWindowIds.add(newWindowId);
          surfacesToDispatch.remove(surfaceId);
        } else {
          // If a bestmatch was already found skip to next iteration
          // Else
          if (!excludedWindowIds.contains(windowId)) {
            print('Adding surface $surfaceId to window $windowId');
            removeSurface(surfaceId, shouldNotify: false);
            switch (windowId) {
              case PersistentWindowId():
                ref
                    .read(
                      persistentWindowStateProvider(windowId).notifier,
                    )
                    .addSurface(surfaceId);
              case EphemeralWindowId():
                ref
                    .read(
                      ephemeralWindowStateProvider(windowId).notifier,
                    )
                    .addSurface(surfaceId);
              case _: // ignore: no_default_cases
            }
            excludedWindowIds.add(windowId);
            surfacesToDispatch.remove(surfaceId);
          }
        }
      });
    }
  }

  void removeSurface(SurfaceId surfaceId, {bool shouldNotify = true}) {
    _closeSurfaceSubscription(surfaceId);
    ref.read(surfaceWindowMapProvider.notifier).unset(surfaceId);
    if (shouldNotify) {
      _onSurfacesChanges();
    }
  }

  void _listenForSurfaceChanges(SurfaceId surfaceId) {
    _closeSurfaceSubscription(surfaceId);

    _surfaceSubscriptions[surfaceId] =
        ref.listen(windowPropertiesStateProvider(surfaceId), (_, next) {
      _onSurfacesChanges();
      if (surfaceId == _displayedSurfaceId) {
        onDisplayedSurfacePropertiesChanged(next);
      }
      //ref.read(matchingEngineProvider.notifier).checkMatching();
    });
  }

  Future<Process?> launchSelf() async {
    final entry = await ref.read(
      localizedDesktopEntryForIdProvider(state.properties.appId).future,
    );

    if (entry == null) {
      return null;
    }
    return ref.read(appLaunchProvider.notifier).launchApplication(
          LaunchConfig.fromDesktopEntry(entry.desktopEntry),
        );
  }

  void onDisplayedSurfacePropertiesChanged(WindowProperties windowProperties);

  void displayedSurfaceChanged(SurfaceId? surfaceId);

  MatchingInfo getMatchingInfo() => _matchingInfo;

  void waitForSurface(int? pid) {
    _matchingInfo = _matchingInfo.copyWith(
      waitingForAppSince: DateTime.now(),
      pid: pid,
    );
  }

  void onSurfaceIsDestroyed(SurfaceId surfaceId) {
    removeSurface(surfaceId);
  }

  void _closeSurfaceSubscription(SurfaceId surfaceId) {
    final subscription = _surfaceSubscriptions[surfaceId];
    if (subscription != null) {
      subscription.close();
      _surfaceSubscriptions.remove(surfaceId);
    }
  }

  void dispose() {
    _keepAliveLink?.close();
  }
}
