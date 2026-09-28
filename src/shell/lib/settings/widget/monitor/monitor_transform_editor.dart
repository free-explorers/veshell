import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';
import 'package:shell/shared/widget/expandable_container.dart';

/// Picks the display transform (rotation / flip) for a monitor.
class MonitorTransformEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<MonitorTransform> {
  const MonitorTransformEditor({
    required this.path,
    required this.property,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<MonitorTransform> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = path.split('.');
    final monitorName = paths[paths.length - 2];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final transform in MonitorTransform.values)
          ListTile(
            title: Text(transform.label),
            onTap: () {
              ref
                  .read(monitorSettingStateProvider(monitorName).notifier)
                  .setTransform(transform);
              ExpandableContainer.of(context).toggle();
            },
          ),
      ],
    );
  }
}
