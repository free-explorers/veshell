import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/overview/helm/widget/helm.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/theme//provider/theme.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/widget/ephemeral_window.dart';

class OverviewContent extends HookConsumerWidget {
  const OverviewContent({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final windowList = ref.watch(
      overviewStateProvider(screenId).select((state) => state.windowList),
    );

    final node = useFocusNode();
    return Material(
      borderRadius: BorderRadius.circular(38),
      color: Theme.of(context).colorScheme.surface.withAlpha(200),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _OverviewContentPanel(),
            const SizedBox(height: 16),
            Expanded(
              child: windowList.isEmpty
                  ? const Helm()
                  : ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(surfaceRadius),
                      ),
                      child: EphemeralWindowWidget(
                        windowId: windowList.first,
                        focusNode: node,
                      ),
                    ),
            ),
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
          const SizedBox(
            width: 16,
          ),
          _EphemeralWindowPanelButton(
            windowId: windowId,
            isFocused: true,
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
  });
  final EphemeralWindowId windowId;
  final bool isFocused;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(ephemeralWindowStateProvider(windowId));
    return Material(
      borderRadius: BorderRadius.circular(24),
      color: isFocused
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surface,
      child: InkWell(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 8,
              ),
              SizedBox(
                height: 32,
                width: 32,
                child: AppIconById(id: window.properties.appId),
              ),
              const SizedBox(
                width: 8,
              ),
              SizedBox(
                child: IconButton(
                  color: isFocused
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  onPressed: () {
                    ref
                        .read(
                          windowManagerProvider.notifier,
                        )
                        .closeWindow(window.windowId);
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
