import 'dart:math';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/widget/number_picker.dart';
import 'package:shell/shared/widget/size_reporter.dart';
import 'package:shell/status_bar/provider/status_bar_settings.dart';
import 'package:shell/status_bar/provider/status_notch_geometry.dart';
import 'package:shell/status_bar/widget/status_notch.dart';
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
    final screenId = CurrentScreenId.of(context);
    // The screen's status notch floats over the end of the tile list, right
    // before the picker: hold its room there, so the tiles scroll under it.
    final notchWidth = ref.watch(
      statusNotchSizeProvider(screenId).select((size) => size.width),
    );
    final isNotchShown = ref.watch(
      statusBarSettingsProvider.select((settings) => settings.showsNotch),
    );
    final notchHolder = isNotchShown
        ? max(0, notchWidth - StatusNotch.pickerOverlap)
        : 0;
    return SizedBox(
      height: preferredSize.height,
      width: preferredSize.width,
      child: Material(
        color: theme.colorScheme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : theme.colorScheme.primary,
        child: Row(
          children: [
            Expanded(
              child: TileableListView(
                tileableList: tileableList,
                endPadding: notchHolder.toDouble(),
              ),
            ),
            // The status notch is placed by the screen right before this.
            SizeReporter(
              onSizeChanged: (size) => ref
                  .read(workspacePanelTrailingWidthProvider(screenId).notifier)
                  .set(size.width),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NumberPicker(
                    allowKeyboardInput: false,
                    value: visibleLength,
                    minValue: 1,
                    onValueChange: onVisibleLengthChange,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  // TODO: implement preferredSize to expand width
  Size get preferredSize => const Size.fromHeight(panelSize);
}
