import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/model/screen.dart';
import 'package:shell/screen/provider/screen.dart';
import 'package:shell/workspace/provider/workspace.dart';
import 'package:shell/workspace/widget/workspace.dart';

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
