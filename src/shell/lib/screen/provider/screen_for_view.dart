import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/provider/monitor_by_view_id.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'screen_for_view.g.dart';

/// The screen that represents [viewId]'s monitor for monitor-level focus: the
/// monitor's primary screen, falling back to its first screen.
///
/// A monitor can be split into several screens; only one of them can be the
/// focus target for placement. The primary screen (the first one configured on
/// the monitor) is the documented deterministic choice.
@riverpod
ScreenId? screenForView(Ref ref, int viewId) {
  final monitorName = ref.watch(monitorByViewIdProvider(viewId));
  if (monitorName == null) {
    return null;
  }
  final screenList = ref
      .watch(monitorConfigurationStateProvider(monitorName))
      .screenList;
  if (screenList.isEmpty) {
    return null;
  }
  final primary =
      screenList.firstWhereOrNull(
        (configuration) => configuration.primaryForMonitor == monitorName,
      ) ??
      screenList.first;
  return primary.screenId;
}
