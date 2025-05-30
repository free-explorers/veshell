import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';

part 'current_monitor.g.dart';

/// Provide the current Monitor to all his childrens
@Riverpod(dependencies: [])
MonitorId currentMonitor(Ref ref) {
  // This provider is instentatied in Children Scope
  throw Exception('Provider was not initialized');
}
