import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/widget/workspace_list.dart';

class ScreenPanel extends HookConsumerWidget implements PreferredSizeWidget {
  const ScreenPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      textStyle: TextStyle(color: theme.colorScheme.onSurface),
      child: const SizedBox(
        width: 48,
        child: WorkspaceListView(),
      ),
    );
  }

  @override
  // TODO: implement preferredSize to expand height
  Size get preferredSize => const Size.fromWidth(48);
}
