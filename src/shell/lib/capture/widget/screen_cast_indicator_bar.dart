import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/capture/provider/screen_cast_indicator.dart';

/// The persistent trusted indicator (capture specification section 8.3):
/// one card per live session, naming the shared target with a Stop
/// action. It survives workspaces because it mounts in the shell rather
/// than the content tree; pausing consumers never hides it.
class ScreenCastIndicatorBar extends HookConsumerWidget {
  const ScreenCastIndicatorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streams = ref.watch(screenCastIndicatorProvider);
    if (streams.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final stream in streams.values)
          Card(
            color: theme.colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_share),
                  const SizedBox(width: 8),
                  // One stream shortcut naming the shared target.
                  Text(stream.sourceLabel.isEmpty
                      ? "Screen sharing active"
                      : "Sharing ${stream.sourceLabel}"),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(screenCastIndicatorProvider.notifier).stop(
                              stream.sessionHandle,
                            ),
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
