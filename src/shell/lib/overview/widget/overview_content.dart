import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/file_explorer/model/directory_path.dart';
import 'package:shell/file_explorer/provider/filtered_entry_list.dart';
import 'package:shell/file_preview/widget/file_preview_view.dart';
import 'package:shell/overview/helm/widget/helm.dart';
import 'package:shell/overview/model/search_mode.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/theme//provider/theme.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/widget/ephemeral_window.dart';

class OverviewContent extends HookConsumerWidget {
  const OverviewContent({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final focusedWindowId = ref.watch(
      overviewStateProvider(screenId).select(
        (state) =>
            state.focusedWindowId ??
            (state.windowList.isEmpty ? null : state.windowList.first),
      ),
    );

    final searchMode = ref.watch(
      overviewStateProvider(screenId).select((state) => state.searchMode),
    );
    final selectedIndex = ref.watch(
      overviewStateProvider(screenId).select((state) => state.selectedIndex),
    );

    // Resolve the selected file to its path for the preview. The selected index
    // refers to the Files mode's filtered list; other modes have no preview.
    DirectoryPath? previewPath;
    final index = selectedIndex;
    if (searchMode == SearchMode.file && index != null) {
      final entryList = ref.watch(filteredEntryListProvider(screenId)).value;
      if (entryList != null && index >= 0 && index < entryList.length) {
        previewPath = entryList[index].path;
      }
    }

    final node = useFocusNode();
    final Widget content;
    if (previewPath != null) {
      content = FilePreviewView(path: previewPath);
    } else if (focusedWindowId == null) {
      content = const Helm();
    } else {
      content = ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(surfaceRadius)),
        child: EphemeralWindowWidget(
          key: ValueKey(focusedWindowId),
          windowId: focusedWindowId,
          focusNode: node,
        ),
      );
    }

    return Material(
      borderRadius: BorderRadius.circular(38),
      color: Theme.of(context).colorScheme.surface.withAlpha(200),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _OverviewContentPanel(),
            const SizedBox(height: 16),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

class _OverviewContentPanel extends HookConsumerWidget {
  const _OverviewContentPanel();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);

    final focusedWindowId = ref.watch(
      overviewStateProvider(screenId).select(
        (state) =>
            state.focusedWindowId ??
            (state.windowList.isEmpty ? null : state.windowList.first),
      ),
    );
    final windowList = ref.watch(
      overviewStateProvider(screenId).select((state) => state.windowList),
    );
    return Row(
      children: [
        IconButton.filled(
          onPressed: () {},
          icon: const Icon(MdiIcons.shipWheel),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(12),
            iconSize: 28,
          ),
        ),
        for (final windowId in windowList) ...[
          const SizedBox(width: 16),
          _EphemeralWindowPanelButton(
            windowId: windowId,
            isFocused: windowId == focusedWindowId,
            onTap: () => ref
                .read(overviewStateProvider(screenId).notifier)
                .focusWindow(windowId),
          ),
        ],
      ],
    );
  }
}

class _EphemeralWindowPanelButton extends HookConsumerWidget {
  const _EphemeralWindowPanelButton({
    required this.windowId,
    this.isFocused = false,
    this.onTap,
  });
  final EphemeralWindowId windowId;
  final bool isFocused;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(ephemeralWindowStateProvider(windowId));

    return Material(
      borderRadius: BorderRadius.circular(24),
      color: isFocused
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                width: 32,
                child: AppIconById(id: window.properties.appId),
              ),
              const SizedBox(width: 8),
              SizedBox(
                child: IconButton(
                  color: isFocused
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  onPressed: () {
                    ref
                        .read(ephemeralWindowStateProvider(windowId).notifier)
                        .closeWindow();
                  },
                  icon: const Icon(MdiIcons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
