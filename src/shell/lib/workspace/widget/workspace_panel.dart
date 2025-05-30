import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/widget/number_picker.dart';
import 'package:shell/theme//provider/theme.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';
import 'package:shell/workspace/widget/tileable_list.dart';

class WorkspacePanel extends HookConsumerWidget implements PreferredSizeWidget {
  const WorkspacePanel({
    required this.tileableList,
    required this.visibleLength,
    required this.onVisibleLengthChange,
    super.key,
  });
  final List<Tileable> tileableList;
  final int visibleLength;
  final void Function(int value) onVisibleLengthChange;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      height: preferredSize.height,
      width: preferredSize.width,
      child: Material(
        color: theme.colorScheme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : theme.colorScheme.primary,
        child: Row(
          children: [
            Expanded(child: TileableListView(tileableList: tileableList)),
            NumberPicker(
              value: visibleLength,
              minValue: 0,
              onValueChange: onVisibleLengthChange,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  @override
  // TODO: implement preferredSize to expand width
  Size get preferredSize => const Size.fromHeight(panelSize);
}
