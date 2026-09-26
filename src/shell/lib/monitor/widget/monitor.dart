import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/capture/widget/capture_prompt_overlay.dart';
import 'package:shell/main.dart';
import 'package:shell/monitor/model/monitor_configuration.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/monitor/provider/monitor_by_view_id.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/monitor/provider/navigator_key_for_view.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/monitor/widget/empty_monitor.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/widget/screen.dart';
import 'package:shell/theme/provider/theme.dart';

/// Widget that represent the Monitor in the widget tree
class MonitorWidget extends HookConsumerWidget {
  /// Const constructor
  const MonitorWidget({required this.viewId, super.key});
  final int viewId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (lightTheme, darkTheme) = ref.watch(veshellThemeProvider);
    final initializationStatus = InitializationStatus.of(context);
    final monitorName = ref.watch(monitorByViewIdProvider(viewId));
    if (monitorName != null) {
      ref.watch(monitorByNameProvider(monitorName));
    }
    // Trusted shell dialogs (Polkit) push on this monitor's navigator.
    final navigatorKey = ref.watch(navigatorKeyForViewProvider(viewId));
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      // The consent picker and screenshot prompt are drawn above the
      // Navigator, frozen on the monitor focused when the flow opened.
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child ?? const SizedBox.shrink(),
          CapturePromptOverlay(monitorName: monitorName),
        ],
      ),
      home: Material(
        child: initializationStatus.when(
          data: (initialized) => HookConsumer(
            builder: (context, ref, child) {
              final monitorName = ref.watch(monitorByViewIdProvider(viewId));
              if (monitorName == null) {
                // The view is gone (or not yet associated with a monitor).
                return const SizedBox.shrink();
              }

              final monitorConfiguration = ref.watch(
                monitorConfigurationStateProvider(monitorName),
              );

              // Only fill a monitor the shell has never configured. A monitor
              // whose screens the user deliberately removed stays empty while
              // it stays connected: a monitor emptied by hotplug reconciliation
              // is refilled by `MonitorManager`, and a brand new monitor is
              // filled here as a fallback when the reconcile listener has not
              // run yet.
              useEffect(() {
                final notifier = ref.read(
                  monitorConfigurationStateProvider(monitorName).notifier,
                );
                if (monitorConfiguration.screenList.isNotEmpty ||
                    notifier.isInitialized) {
                  return null;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final currentConfiguration = ref.read(
                    monitorConfigurationStateProvider(monitorName),
                  );
                  final currentNotifier = ref.read(
                    monitorConfigurationStateProvider(monitorName).notifier,
                  );
                  if (currentConfiguration.screenList.isNotEmpty ||
                      currentNotifier.isInitialized) {
                    return;
                  }
                  final newScreenId = ref
                      .read(screenManagerProvider.notifier)
                      .createNewScreen();
                  currentNotifier.addNewScreenConfiguration(newScreenId);
                });
                return null;
              }, [monitorName, monitorConfiguration.screenList]);
              return CurrentMonitorName(
                name: monitorName,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (monitorConfiguration.screenList.isEmpty)
                      EmptyMonitor(monitorName: monitorName)
                    else
                      Flex(
                        direction: switch (monitorConfiguration.displayMode) {
                          ScreenDisplayMode.splitVertical => Axis.vertical,
                          ScreenDisplayMode.splitHorizontal => Axis.horizontal,
                        },
                        children: [
                          for (final screenConfiguration
                              in monitorConfiguration.screenList) ...[
                            Flexible(
                              flex: screenConfiguration.flex,
                              child: ScreenWidget(
                                screenId: screenConfiguration.screenId,
                              ),
                            ),
                            if (screenConfiguration !=
                                monitorConfiguration.screenList.last)
                              ScreenDivider(
                                screenA: screenConfiguration,
                                screenB:
                                    monitorConfiguration
                                        .screenList[monitorConfiguration
                                            .screenList
                                            .indexOf(screenConfiguration) +
                                        1],
                                displayMode: monitorConfiguration.displayMode,
                              ),
                          ],
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}

class ScreenDivider extends HookConsumerWidget {
  const ScreenDivider({
    required this.screenA,
    required this.screenB,
    required this.displayMode,
    super.key,
  });

  final ScreenConfiguration screenA;
  final ScreenConfiguration screenB;
  final ScreenDisplayMode displayMode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitorName = CurrentMonitorName.of(context);
    final monitor = ref.watch(monitorByNameProvider(monitorName))!;
    final cumulatedDelta = useState<double>(0);
    final resizeInProgress = useState(false);
    return GestureDetector(
      onPanStart: (details) {
        resizeInProgress.value = true;
      },
      onPanUpdate: (details) {
        final relativeDimension = switch (displayMode) {
          ScreenDisplayMode.splitVertical => monitor.currentMode!.size.height,
          ScreenDisplayMode.splitHorizontal => monitor.currentMode!.size.width,
        };
        final step = relativeDimension / 100;
        final delta = switch (displayMode) {
          ScreenDisplayMode.splitVertical => details.delta.dy,
          ScreenDisplayMode.splitHorizontal => details.delta.dx,
        };

        // Accumulate the delta
        cumulatedDelta.value += delta;

        // Calculate how many steps we need to move
        final numOfSteps = (cumulatedDelta.value / step).truncate();

        if (numOfSteps != 0) {
          // Consume only the portion corresponding to complete steps.
          cumulatedDelta.value -= numOfSteps * step;

          // Calculate new flex values
          final newFlexA = screenA.flex + numOfSteps;
          final newFlexB = screenB.flex - numOfSteps;

          // Prevent extremely small or negative flex values.
          const minFlex = 5; // Minimum flex value (5%)
          if (newFlexA >= minFlex && newFlexB >= minFlex) {
            ref
                .read(monitorConfigurationStateProvider(monitorName).notifier)
                .updateFlexForConfiguration(screenA, newFlexA);
            ref
                .read(monitorConfigurationStateProvider(monitorName).notifier)
                .updateFlexForConfiguration(screenB, newFlexB);
          }
        }
      },
      onPanEnd: (details) {
        resizeInProgress.value = false;
      },
      child: MouseRegion(
        cursor: switch (displayMode) {
          ScreenDisplayMode.splitVertical => SystemMouseCursors.resizeUpDown,
          ScreenDisplayMode.splitHorizontal =>
            SystemMouseCursors.resizeLeftRight,
        },
        child: switch (displayMode) {
          ScreenDisplayMode.splitVertical => const Divider(
            thickness: 4,
            height: 4,
            color: Colors.black,
          ),
          ScreenDisplayMode.splitHorizontal => const VerticalDivider(
            thickness: 4,
            width: 4,
            color: Colors.black,
          ),
        },
      ),
    );
  }
}
