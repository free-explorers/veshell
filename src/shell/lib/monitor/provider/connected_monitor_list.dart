import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/platform/model/event/wayland_event.serializable.dart';
import 'package:shell/platform/provider/wayland.manager.dart';

part 'connected_monitor_list.g.dart';

/// Provide list of plugged Monitors
@riverpod
class ConnectedMonitorList extends _$ConnectedMonitorList {
  @override
  List<Monitor> build() {
    ref.watch(waylandManagerProvider).listen(
      (next) {
        if (next case final MonitorLayoutChangedEvent event) {
          print('MonitorLayoutChangedEvent received : $event');
          state = event.message.monitors;
        }
      },
    );
    return [];
  }
}
