import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';

class MonitorResolutionValue extends HookConsumerWidget {
  const MonitorResolutionValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = path.split('.');
    final monitorName = paths[paths.length - 2];
    final currentMode = ref
        .watch(monitorByNameProvider(monitorName))
        ?.currentMode;
    if (currentMode == null) {
      return Text(context.l10n.notSet);
    }
    return Text(
      context.l10n.dimensions(
        currentMode.size.width.round(),
        currentMode.size.height.round(),
      ),
    );
  }
}
