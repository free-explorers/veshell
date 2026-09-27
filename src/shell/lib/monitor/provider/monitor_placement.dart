import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_arrangement.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';

part 'monitor_placement.g.dart';

/// Desired logical placement of every connected monitor, for the arrangement
/// canvas.
///
/// Merges the live monitor projection (connector, current mode) with the
/// desired geometry from `MonitorSettingState`, which carries the fractional
/// scale and the user-authored location. See
/// `docs/specifications/monitor.md`.
@riverpod
List<MonitorPlacement> monitorPlacements(Ref ref) {
  final monitors = ref.watch(connectedMonitorListProvider);
  return [
    for (final monitor in monitors)
      MonitorPlacement.fromMonitor(
        monitor: monitor,
        scale: ref
            .watch(monitorSettingStateProvider(monitor.name))
            .fractionnalScale,
      ),
  ];
}
