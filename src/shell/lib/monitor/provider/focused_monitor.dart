import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/monitor_for_screen.dart';

part 'focused_monitor.g.dart';

/// The monitor a trusted shell prompt should surface on: the monitor that
/// owns the focused Veshell Screen.
///
/// Falls back to the first connected monitor only while no Screen exists
/// yet (early startup), never as a steady-state default.
@riverpod
Monitor? focusedMonitor(Ref ref) {
  final screenId = ref.watch(focusedScreenProvider);
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
