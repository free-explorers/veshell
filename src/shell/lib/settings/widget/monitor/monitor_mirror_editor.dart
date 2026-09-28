import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';
import 'package:shell/shared/widget/expandable_container.dart';

/// Picks the monitor this one mirrors, or "None" for a regular display.
class MonitorMirrorEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<String?> {
  const MonitorMirrorEditor({
    required this.path,
    required this.property,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<String?> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = path.split('.');
    final monitorName = paths[paths.length - 2];
    final monitors = ref.watch(connectedMonitorListProvider);

    void select(String? monitorId) {
      ref
          .read(monitorSettingStateProvider(monitorName).notifier)
          .setMirrorOf(monitorId);
      ExpandableContainer.of(context).toggle();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(title: const Text('None'), onTap: () => select(null)),
        for (final monitor in monitors.where((m) => m.name != monitorName))
          ListTile(
            title: Text(monitor.name),
            subtitle: Text(monitor.description),
            onTap: () => select(monitor.name),
          ),
      ],
    );
  }
}
