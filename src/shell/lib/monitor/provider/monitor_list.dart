import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/wayland/model/event/wayland_event.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'monitor_list.g.dart';

/// Provide list of plugged Monitors
@riverpod
class MonitorList extends _$MonitorList {
  @override
  List<Monitor> build() {
    ref.listen(
      waylandManagerProvider,
      (_, next) {
        if (next case AsyncData(value: final MonitorLayoutChangedEvent event)) {
          print('MonitorLayoutChangedEvent received : $event');
          state = event.message.monitors;
        }
      },
      fireImmediately: true,
    );
    return [];
  }
}
