import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/dev_tools/provider/matching_logs.dart';
import 'package:shell/dev_tools/widget/state_dev_view.dart';
import 'package:shell/dev_tools/widget/surface_list_dev_view.dart';
import 'package:shell/dev_tools/widget/window_list_dev_view.dart';
import 'package:shell/l10n/l10n.dart';

enum DevToolCategories { state, matching, surfaces, windows }

class DevToolsOverview extends HookConsumerWidget {
  const DevToolsOverview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = useState(DevToolCategories.state);
    return Material(
      color: Theme.of(context).colorScheme.surface.withAlpha(240),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 300,
            child: ListView(
              children: DevToolCategories.values
                  .map(
                    (e) => ListTile(
                      selected: selectedCategory.value == e,
                      title: switch (e) {
                        DevToolCategories.state => Text(context.l10n.state),
                        DevToolCategories.matching => Text(
                          context.l10n.matching,
                        ),
                        DevToolCategories.surfaces => Text(
                          context.l10n.surfaces,
                        ),
                        DevToolCategories.windows => Text(context.l10n.windows),
                      },
                      onTap: () => selectedCategory.value = e,
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface.withAlpha(240),
              child: switch (selectedCategory.value) {
                DevToolCategories.state => const StateDevView(),
                DevToolCategories.matching => const MatchingDebugguer(),
                DevToolCategories.surfaces => const SurfaceListDevView(),
                DevToolCategories.windows => const WindowListDevView(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MatchingDebugguer extends HookConsumerWidget {
  const MatchingDebugguer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(matchingLogsProvider);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Text(log);
        },
      ),
    );
  }
}
