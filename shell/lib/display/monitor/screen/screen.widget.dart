import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:veshell/display/monitor/screen/workspace/workspace.widget.dart';

/// Widget that represent the Screen in the widget tree
class ScreenWidget extends HookConsumerWidget {
  /// Const constructor
  const ScreenWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const worskpaceList = [];
    return const Stack(
      fit: StackFit.expand,
      children: [WorkspaceWidget()],
    );
  }
}
