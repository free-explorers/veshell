import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';

part 'monitor_by_view_id.g.dart';

@riverpod
String? monitorByViewId(Ref ref, int viewId) {
  final monitorList = ref.watch(connectedMonitorListProvider);
  return monitorList
      .firstWhereOrNull((element) => element.viewId == viewId)
      ?.name;
}
