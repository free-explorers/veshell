import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/provider/monitor_layout_received.dart';
import 'package:shell/monitor/provider/monitor_manager.dart';

part 'active_monitor_ids.g.dart';

/// The monitors that currently own their screens.
///
/// Once the compositor has published a layout this is exactly the connected
/// monitors, so a monitor that is unplugged releases its screens (they appear
/// in `availableScreenList` and `monitorForScreen` stops reporting their old
/// owner). Before the first layout event the connected list is only the empty
/// initial value, so the persisted registry is used instead to avoid releasing
/// every screen during startup.
@riverpod
ISet<MonitorId> activeMonitorIds(Ref ref) {
  // Kept alive eagerly so `MonitorManager` is always built (and its hotplug
  // reconcile listener registered), even once ownership switches to the
  // connected list below.
  final knownMonitorIds = ref.watch(
    monitorManagerProvider.select((value) => value.knownMonitorIds),
  );
  if (!ref.watch(monitorLayoutReceivedProvider)) {
    return knownMonitorIds;
  }
  return ref
      .watch(connectedMonitorListProvider)
      .map((monitor) => monitor.name)
      .toISet();
}
