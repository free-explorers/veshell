import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/window/model/ephemeral_window.dart';
import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

mixin WindowProviderMixin<T extends Window> {
  T get state;
  set state(T value);
  AutoDisposeNotifierProviderRef<T> get ref;
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
    _matchingInfo = MatchingInfo.fromWindowProperties(
      window.properties,
    );
    if (state.metaWindowId != null) {
      addMetaWindow(state.metaWindowId!);
    }
  }

  /// Assign a surface to a Window subscribing to any changes
  void addMetaWindow(MetaWindowId metaWindowId) {
    _matchingInfo = _matchingInfo.copyWith(
      waitingForAppSince: null,
    );
    ref.read(metaWindowWindowMapProvider.notifier).set(
          metaWindowId,
          state.windowId,
        );
    _listenForMetaWindowChanges(metaWindowId);
    _onMetaWindowsChanges();
  }

  /// When surfaces are added, removed or updated
  /// we need to determine which surface should be displayed
  /// and try to find best matches for the other surfaces
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
      _debouncedTimer = Timer(
        const Duration(milliseconds: 100),
        () {
          if (_metaWindowSubscriptions.length > 1) {
            _dispatchExtraMetaWindows();
          }
        },
      );
    }

    if (newDisplayedMetaWindowId != _displayedMetaWindowId) {
      _displayedMetaWindowId = newDisplayedMetaWindowId;
      print('new displayed meta window: $_displayedMetaWindowId');
      onCurrentlyDisplayedMetaWindowChanged(_displayedMetaWindowId);
    }
  }

  // For each surface that is not the displayed surface
  // either find a better match or create a new window for it
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
      final sortedEntries = bestMatchForMetaWindowMap.entries.sorted(
        (entry1, entry2) =>
            (entry2.value.$2 ?? 0).compareTo(entry1.value.$2 ?? 0),
      );

      for (final entry in sortedEntries) {
        final metaWindowId = entry.key;
        final (windowId, score) = entry.value;

        // If there is no windowId, create a new one
        if (windowId == null) {
          print('Creating new window for metaWindow $metaWindowId');
          removeMetaWindow(metaWindowId, shouldNotify: false);

          final newWindowId = await switch (state.windowId) {
            PersistentWindowId() => ref
                .read(windowManagerProvider.notifier)
                .createPersistentWindowForMetaWindow(
                  metaWindowId: metaWindowId,
                ),
            EphemeralWindowId() => Future.value(
                ref
                    .read(windowManagerProvider.notifier)
                    .createEphemeralWindowForMetaWindow(
                      metaWindowId: metaWindowId,
                      screenId: (state as EphemeralWindow).screenId,
                    ),
              ),
            _ => throw UnimplementedError(),
          };

          excludedWindowIds.add(newWindowId);
          metaWindowsToDispatch.remove(metaWindowId);
        } else {
          // If a bestmatch was already found skip to next iteration
          // Else
          if (!excludedWindowIds.contains(windowId)) {
            print('Adding metaWindow $metaWindowId to window $windowId');
            removeMetaWindow(metaWindowId, shouldNotify: false);
            switch (windowId) {
              case PersistentWindowId():
                ref
                    .read(
                      persistentWindowStateProvider(windowId).notifier,
                    )
                    .addMetaWindow(metaWindowId);
              case EphemeralWindowId():
                ref
                    .read(
                      ephemeralWindowStateProvider(windowId).notifier,
                    )
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

  void _listenForMetaWindowChanges(MetaWindowId surfaceId) {
    _closeMetaWindowSubscription(surfaceId);

    _metaWindowSubscriptions[surfaceId] =
        ref.listen(metaWindowStateProvider(surfaceId), (_, next) {
      _onMetaWindowsChanges();
      if (surfaceId == _displayedMetaWindowId) {
        onMetaWindowDisplayedPropertiesChanged(next);
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

  void onMetaWindowDisplayedPropertiesChanged(MetaWindow metaWindow);

  void onCurrentlyDisplayedMetaWindowChanged(MetaWindowId? metaWindowId);

  MatchingInfo getMatchingInfo() => _matchingInfo;

  void waitForSurface(int? pid) {
    _matchingInfo = _matchingInfo.copyWith(
      waitingForAppSince: DateTime.now(),
      pid: pid,
    );
  }

  void onMetaWindowIsDestroyed(MetaWindowId metaWindowId) {
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
}
