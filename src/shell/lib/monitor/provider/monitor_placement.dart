import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/effective_mirror_source.dart';
import 'package:shell/monitor/provider/monitor_arrangement.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';

part 'monitor_placement.g.dart';

/// Desired logical placement of every connected, non-mirroring monitor, for
/// the arrangement canvas.
///
/// Merges the live monitor projection (connector, current mode) with the
/// desired geometry from `MonitorSettingState`, which carries the fractional
/// scale, transform and the user-authored location. Mirrored monitors are
/// excluded: they present another monitor's content and are not positioned on
/// their own. See `docs/specifications/monitor.md`.
@riverpod
List<MonitorPlacement> monitorPlacements(Ref ref) {
  final monitors = ref.watch(connectedMonitorListProvider);
  final placements = <MonitorPlacement>[];
  for (final monitor in monitors) {
    if (ref.watch(effectiveMirrorSourceProvider(monitor.name)) != null) {
      continue;
    }
    final setting = ref.watch(monitorSettingStateProvider(monitor.name));
    placements.add(
      MonitorPlacement.fromMonitor(
        monitor: monitor,
        scale: setting.fractionnalScale,
        transposed: setting.transform.isTransposed,
      ),
    );
  }
  return placements;
}
