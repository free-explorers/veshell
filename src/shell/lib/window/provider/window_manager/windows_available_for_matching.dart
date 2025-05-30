import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'windows_available_for_matching.g.dart';

/// List of windows that are available for matching.
/// So it consider only windows in active screens in active monitors
@riverpod
List<WindowId> windowsAvailableForMatching(Ref ref) {
  final monitorList = ref.watch(connectedMonitorListProvider);
  final windowList = <WindowId>[];
  for (final monitor in monitorList) {
    final monitorConfiguration =
        ref.watch(monitorConfigurationStateProvider(monitor.name));
    for (final screenConfiguration in monitorConfiguration.screenList) {
      final screen =
          ref.watch(screenStateProvider(screenConfiguration.screenId));
      for (final workspaceId in screen.workspaceList) {
        final workspace = ref.watch(workspaceStateProvider(workspaceId));
        for (final windowId in workspace.tileableWindowList) {
          windowList.add(windowId);
        }
      }
    }
  }

  final ephemeralWindowList =
      ref.watch(windowManagerProvider).windows.whereType<EphemeralWindowId>();

  windowList.addAll(ephemeralWindowList);

  return windowList;
}
