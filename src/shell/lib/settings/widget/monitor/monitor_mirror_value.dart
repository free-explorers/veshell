import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

/// Shows the monitor a monitor mirrors, or "None" for a regular display.
class MonitorMirrorValue extends ConsumerWidget {
  const MonitorMirrorValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(jsonValueByPathProvider(path)) as String?;
    return Text(value ?? 'None');
  }
}
