import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/monitor/model/monitor_configuration.serializable.dart';
import 'package:shell/monitor/provider/current_monitor.dart';
import 'package:shell/monitor/provider/monitor_configuration_state.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/screen/provider/available_screen_list.dart';
import 'package:shell/screen/provider/monitor_for_screen.dart';
import 'package:shell/screen/provider/screen_label.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/provider/screen_state.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/widget/number_picker.dart';
import 'package:shell/theme/provider/theme.dart';

class ScreenConfigurationMenu extends HookConsumerWidget {
  const ScreenConfigurationMenu({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuController = useMemoized(MenuController.new);
    final monitor = ref.watch(currentMonitorProvider);
    final screenId = CurrentScreenId.of(context);

    final screenConfiguration =
        ref.watch(monitorConfigurationStateProvider(monitor));
    return MenuAnchor(
      controller: menuController,
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
      ),
      alignmentOffset: const Offset(4, -44),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  'Screens',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              NumberPicker(
                value: screenConfiguration.screenList.length,
                onValueChange: (value) {
                  if (value > screenConfiguration.screenList.length) {
                    var screenToUse =
                        ref.watch(availableScreenListProvider).firstOrNull;
                    screenToUse ??= ref
                        .read(screenManagerProvider.notifier)
                        .createNewScreen();
                    ref
                        .read(
                          monitorConfigurationStateProvider(monitor).notifier,
                        )
                        .addNewScreenConfiguration(screenToUse);
                  } else {
                    ref
                        .read(
                          monitorConfigurationStateProvider(monitor).notifier,
                        )
                        .removeLastScreenConfiguration();
                  }
                },
              ),
              IconButton(
                onPressed: () {
                  ref
                      .read(
                        monitorConfigurationStateProvider(monitor).notifier,
                      )
                      .setDisplayMode(
                        switch (screenConfiguration.displayMode) {
                          ScreenDisplayMode.splitVertical =>
                            ScreenDisplayMode.splitHorizontal,
                          ScreenDisplayMode.splitHorizontal =>
                            ScreenDisplayMode.splitVertical,
                        },
                      );
                },
                icon: RotatedBox(
                  quarterTurns: switch (screenConfiguration.displayMode) {
                    ScreenDisplayMode.splitVertical => 0,
                    ScreenDisplayMode.splitHorizontal => 1
                  },
                  child: const Icon(MdiIcons.viewAgenda),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        SizedBox(
          width: 500,
          height: 300,
          child: ScreenPicker(
            currentScreenId: screenId,
            onScreenSelected: (newScreenId) {
              final currentMonitorForScreen =
                  ref.read(monitorForScreenProvider(newScreenId));
              if (currentMonitorForScreen != null) {
                ref
                    .read(monitorConfigurationStateProvider(monitor).notifier)
                    .swapScreenIds(
                      screenId,
                      newScreenId,
                    );
              } else {
                ref
                    .read(monitorConfigurationStateProvider(monitor).notifier)
                    .replaceScreenIdByScreenId(
                      screenId,
                      newScreenId,
                    );
              }
              menuController.close();
            },
          ),
        ),
      ],
      child: IconButton(
        constraints: const BoxConstraints(
          minWidth: panelSize,
          minHeight: panelSize,
        ),
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          iconSize: 24,
          padding: EdgeInsets.zero,
        ),
        onPressed: () => menuController.isOpen
            ? menuController.close()
            : menuController.open(),
        icon: const Icon(MdiIcons.monitorDashboard),
      ),
    );
  }
}

class ScreenPicker extends HookConsumerWidget {
  const ScreenPicker({this.currentScreenId, this.onScreenSelected, super.key});

  final ScreenId? currentScreenId;
  final void Function(
    ScreenId screenId,
  )? onScreenSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenList = ref.watch(
      screenManagerProvider.select(
        (value) => value.screenIds,
      ),
    );

    return ListView.builder(
      itemCount: screenList.length + 1,
      itemBuilder: (context, index) {
        if (index == screenList.length) {
          return ListTile(
            leading: const Icon(MdiIcons.plus),
            title: const Text('Create new screen'),
            onTap: () {
              final newScreenId =
                  ref.read(screenManagerProvider.notifier).createNewScreen();
              onScreenSelected?.call(newScreenId);
            },
          );
        }
        final screenId = screenList[index];
        return ScreenListTile(
          screenId: screenId,
          selected: screenId == currentScreenId,
          onTap: () {
            onScreenSelected?.call(screenId);
          },
        );
      },
    );
  }
}

class ScreenListTile extends HookConsumerWidget {
  const ScreenListTile({
    required this.screenId,
    this.onTap,
    this.selected = false,
    super.key,
  });
  final ScreenId screenId;
  final GestureTapCallback? onTap;
  final bool selected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenLabel = ref.watch(screenLabelProvider(screenId));
    final monitorIdForScreen = ref.watch(monitorForScreenProvider(screenId));
    return ListTile(
      leading: selected
          ? const Icon(MdiIcons.check)
          : monitorIdForScreen != null
              ? const Icon(MdiIcons.swapVertical)
              : const Icon(MdiIcons.radioboxBlank),
      title: Text(screenLabel.value ?? ''),
      subtitle: monitorIdForScreen != null
          ? Text(
              monitorIdForScreen,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          : null,
      selected: selected,
      onTap: onTap,
      trailing: PopupMenuButton(
        itemBuilder: (context) {
          return [
            PopupMenuItem<void>(
              child: const ListTile(
                leading: Icon(MdiIcons.pencil),
                title: Text('Rename'),
              ),
              onTap: () async {
                final newLabel = await showDialog<String?>(
                  context: context,
                  builder: (context) => const RenameScreenDialog(),
                );
                ref
                    .read(screenStateProvider(screenId).notifier)
                    .setCustomLabel(newLabel);
              },
            ),
            PopupMenuItem<void>(
              child: const ListTile(
                leading: Icon(MdiIcons.delete),
                title: Text('Delete'),
              ),
              onTap: () {
                final monitorId = ref.read(monitorForScreenProvider(screenId));
                if (monitorId != null) {
                  var screenToUse =
                      ref.watch(availableScreenListProvider).firstOrNull;
                  screenToUse ??= ref
                      .read(screenManagerProvider.notifier)
                      .createNewScreen();

                  ref
                      .read(
                        monitorConfigurationStateProvider(monitorId).notifier,
                      )
                      .replaceScreenIdByScreenId(
                        screenId,
                        screenToUse,
                      );
                }
                ref.read(screenManagerProvider.notifier).removeScreen(screenId);
              },
            ),
          ];
        },
      ),
    );
  }
}

class RenameScreenDialog extends HookConsumerWidget {
  const RenameScreenDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newLabel = useState<String?>(null);
    return AlertDialog(
      title: const Text('Rename Screen'),
      content: TextField(
        onSubmitted: (value) => Navigator.of(context).pop(value),
        autofocus: true,
        onChanged: (value) {
          newLabel.value = value;
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(newLabel.value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
