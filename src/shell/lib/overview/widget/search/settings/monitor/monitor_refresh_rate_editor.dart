import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/state/monitor_setting.dart';
import 'package:shell/shared/widget/expandable_container.dart';

class MonitorRefreshRateEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<MonitorRefreshRate> {
  const MonitorRefreshRateEditor({
    required this.path,
    required this.property,
    required this.onChanged,
    super.key,
  });
  @override
  final String path;

  @override
  final SettingProperty<MonitorRefreshRate> property;

  @override
  final void Function(MonitorRefreshRate newValue) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = path.split('.');
    final monitorName = paths[paths.length - 2];
    final monitor = ref.watch(monitorByNameProvider(monitorName))!;
    final currentMode = monitor.currentMode!;

    final modeList =
        monitor.modes.where((mode) => mode.size == currentMode.size);
    final modeMapPerRefreshRate = <int, List<Mode>>{};
    for (final mode in modeList) {
      modeMapPerRefreshRate.putIfAbsent(mode.refreshRate, () => []).add(mode);
    }
    return ListView.builder(
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final refreshRate = modeMapPerRefreshRate.keys.elementAt(index);
        return ListTile(
          onTap: () {
            final mode = modeMapPerRefreshRate[refreshRate]!.first;
            ref
                .read(monitorSettingProvider(monitorName).notifier)
                .setMode(mode);
            onChanged(
              refreshRate,
            );

            ExpandableContainer.of(context).toggle();
          },
          title: Text(
            '${(refreshRate / 1000).round()} Hz',
          ),
        );
      },
      itemCount: modeMapPerRefreshRate.length,
    );
  }
}
