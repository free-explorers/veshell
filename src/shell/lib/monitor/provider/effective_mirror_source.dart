import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';

part 'effective_mirror_source.g.dart';

/// Connector name of the monitor [monitorId] effectively mirrors right now, or
/// `null` when it is a regular display.
///
/// Mirrors Rust's resolution (`State::mirror_source`): the configured target
/// must be connected and must itself be a regular display (not configured to
/// mirror); otherwise the monitor falls back to a regular display. See
/// `docs/specifications/monitor.md` (section "Mirroring").
@riverpod
String? effectiveMirrorSource(Ref ref, MonitorId monitorId) {
  final target = ref.watch(monitorSettingStateProvider(monitorId)).mirrorOf;
  if (target == null || target == monitorId) {
    return null;
  }
  final connectedNames = ref
      .watch(connectedMonitorListProvider)
      .map((monitor) => monitor.name)
      .toSet();
  if (!connectedNames.contains(target)) {
    return null;
  }
  // One level deep: a target that is itself configured to mirror is not a
  // valid source (Rust's `mirror_of.contains_key(target)`).
  if (ref.watch(monitorSettingStateProvider(target)).mirrorOf != null) {
    return null;
  }
  return target;
}
