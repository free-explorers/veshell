import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/screen.model.dart';
import 'package:shell/display/monitor/screen/screen.provider.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.provider.dart';
import 'package:shell/display/monitor/screen/workspace/workspace.widget.dart';

/// Widget that represent the Screen in the widget tree
class ScreenWidget extends HookConsumerWidget {
  /// Const constructor
  const ScreenWidget({required this.screenId, super.key});
  final ScreenId screenId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenState = ref.watch(screenStateProvider(screenId));

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final workspaceId in screenState.workspaceList)
          ProviderScope(
            overrides: [
              currentWorkspaceIdProvider.overrideWith((ref) => workspaceId),
            ],
            child: const WorkspaceWidget(),
          ),
      ],
    );
  }
}
