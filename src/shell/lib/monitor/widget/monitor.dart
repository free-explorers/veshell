import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/main.dart';
import 'package:shell/monitor/model/monitor_configuration.serializable.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/test_theme.dart';
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
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      /* home: Material(
        child: initializationStatus.when(
          data: (initialized) => HookConsumer(
            builder: (context, ref, child) {
              final monitorName = ref.watch(monitorByViewIdProvider(viewId));
              if (monitorName == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final monitorConfiguration = ref.watch(
                monitorConfigurationStateProvider(monitorName),
              );

              useEffect(
                () {
                  if (monitorConfiguration.screenList.isEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final newScreenId = ref
                          .read(screenManagerProvider.notifier)
                          .createNewScreen();
                      ref
                          .read(
                            monitorConfigurationStateProvider(monitorName)
                                .notifier,
                          )
                          .addNewScreenConfiguration(newScreenId);
                    });
                  }
                  return null;
                },
                [monitorConfiguration.screenList],
              );
              return CurrentMonitorName(
                name: monitorName,
                child: Flex(
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
                          screenB: monitorConfiguration.screenList[
                              monitorConfiguration.screenList
                                      .indexOf(screenConfiguration) +
                                  1],
                          displayMode: monitorConfiguration.displayMode,
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => Center(
            child: Text(error.toString()),
          ),
        ),
      ), */
      home: const TextThemeComparison(),
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
    final monitorConfiguration = ref.watch(
      monitorConfigurationStateProvider(monitorName),
    );
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
          // Only consume the portion of cumulated delta that corresponds to complete steps
          cumulatedDelta.value -= numOfSteps * step;

          // Calculate new flex values
          final newFlexA = screenA.flex + numOfSteps;
          final newFlexB = screenB.flex - numOfSteps;

          // Apply constraints to prevent extremely small or negative flex values
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
