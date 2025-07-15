import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';
import 'package:shell/shared/widget/expandable_container.dart';

class MonitorResolutionEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<MonitorResolution> {
  const MonitorResolutionEditor({
    required this.path,
    required this.property,
    super.key,
  });
  @override
  final String path;

  @override
  final SettingProperty<MonitorResolution> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = path.split('.');
    final monitorName = paths[paths.length - 2];
    final modeList = ref.watch(monitorByNameProvider(monitorName))?.modes ?? [];
    final modeMapPerSize = <Size, List<Mode>>{};
    for (final mode in modeList) {
      modeMapPerSize.putIfAbsent(mode.size, () => []).add(mode);
    }
    return ListView.builder(
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final size = modeMapPerSize.keys.elementAt(index);
        return ListTile(
          onTap: () {
            final mode = modeMapPerSize[size]!.first;
            ref
                .read(monitorSettingStateProvider(monitorName).notifier)
                .setMode(mode);

            ExpandableContainer.of(context).toggle();
          },
          title: Text(
            '${size.width.round()} x ${size.height.round()}',
          ),
        );
      },
      itemCount: modeMapPerSize.length,
    );
  }
}
