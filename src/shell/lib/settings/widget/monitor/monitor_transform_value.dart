import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

/// Shows the desired display transform of a monitor.
class MonitorTransformValue extends ConsumerWidget {
  const MonitorTransformValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(jsonValueByPathProvider(path));
    final transform = MonitorTransform.values.firstWhere(
      (transform) => transform.name == value,
      orElse: () => MonitorTransform.normal,
    );
    return Text(transform.label(context.l10n));
  }
}
