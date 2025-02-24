import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_list.dart';

part 'monitor_by_name.g.dart';

/// Provide list of plugged Monitors
@riverpod
class MonitorByName extends _$MonitorByName {
  @override
  Monitor? build(String monitorName) {
    final monitorList = ref.watch(monitorListProvider);
    return monitorList
        .firstWhereOrNull((element) => element.name == monitorName);
  }
}
