import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/screen/provider/monitor_for_screen.dart';
import 'package:shell/screen/provider/pointer_screen.dart';

part 'focused_monitor.g.dart';

/// The monitor a trusted shell prompt should surface on: the monitor that
/// owns the placement screen.
///
/// The placement screen is the one under the pointer (falling back to the
/// focused screen until the pointer entered one), so this follows the pointer
/// without requiring a click. A prompt that takes the keyboard moves the
/// keyboard's monitor there itself. Falls back to the first
/// connected monitor in compositor layout order only while no Screen exists
/// yet (early startup), never as a steady-state default.
@riverpod
Monitor? focusedMonitor(Ref ref) {
  final screenId = ref.watch(placementScreenProvider);
  if (screenId != null) {
    final monitorId = ref.watch(monitorForScreenProvider(screenId));
    if (monitorId != null) {
      final monitor = ref.watch(monitorByNameProvider(monitorId));
      if (monitor != null) {
        return monitor;
      }
    }
  }
  final monitors = ref.watch(connectedMonitorListProvider);
  return monitors.isEmpty ? null : monitors.first;
}
