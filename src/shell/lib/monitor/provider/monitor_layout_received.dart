import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'monitor_layout_received.g.dart';

/// Whether the compositor has published an authoritative monitor layout yet.
///
/// The connected monitor list starts empty, so it is indistinguishable from
/// "no monitor is connected" until the first [MonitorLayoutChangedEvent]
/// arrives. `activeMonitorIds` uses this flag to keep using the persisted
/// monitor registry until then, so startup does not transiently release every
/// screen from its monitor.
@Riverpod(keepAlive: true)
class MonitorLayoutReceived extends _$MonitorLayoutReceived {
  @override
  bool build() {
    ref.watch(platformManagerProvider).listen((event) {
      if (event is MonitorLayoutChangedEvent) {
        state = true;
      }
    });
    return false;
  }
}
