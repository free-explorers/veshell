import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'connected_monitor_list.g.dart';

/// Provide list of plugged Monitors
@riverpod
class ConnectedMonitorList extends _$ConnectedMonitorList {
  @override
  List<Monitor> build() {
    ref.watch(platformManagerProvider).listen(
      (next) {
        if (next case final MonitorLayoutChangedEvent event) {
          state = event.message.monitors;
        }
      },
    );
    return [];
  }
}
