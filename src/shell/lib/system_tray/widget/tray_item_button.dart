import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/system_tray/model/tray_item.dart';
import 'package:shell/system_tray/model/tray_menu.dart';
import 'package:shell/system_tray/model/tray_properties.dart';
import 'package:shell/system_tray/provider/system_tray_manager.dart';
import 'package:shell/system_tray/widget/tray_item_icon.dart';

/// How far a touchpad scrolls for one `Scroll` step; a mouse wheel notch is
/// one step whatever its pixel delta.
const _scrollStepPixels = 50.0;

/// A tray item's icon, driving the item like a desktop tray does:
///
/// * primary click: `Activate`, or the menu when the item is only a menu (or
///   does not implement `Activate`);
/// * secondary click: the menu;
/// * middle click: `SecondaryActivate`;
/// * scroll: `Scroll`.
///
/// Its tooltip names the item and adds the application's description.
class TrayItemButton extends HookConsumerWidget {
  const TrayItemButton({
    required this.item,
    required this.iconSize,
    this.padding = const EdgeInsets.all(4),
    super.key,
  });

  final TrayItem item;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(systemTrayManagerProvider.notifier);
    final menuController = useMemoized(MenuController.new);
    final menu = useState<TrayMenuEntry?>(null);
    final client = useMemoized(() => manager.menuClient(item.id), [
      item.id,
      item.menuPath,
    ]);
    final scrollRemainder = useRef(Offset.zero);

    Future<void> reloadMenu() async {
      final root = await client?.layout();
      if (root != null && context.mounted) menu.value = root;
    }

    // While the menu is open, follow the application's changes to it (a
    // toggled checkbox, an entry it adds).
    final isOpen = useState(false);
    useEffect(() {
      if (!isOpen.value || client == null) return null;
      final subscription = client.changes.listen((_) => reloadMenu());
      return subscription.cancel;
    }, [isOpen.value, client]);

    Future<void> openMenu(Offset globalPosition) async {
      if (client == null) {
        await manager.contextMenu(item.id, globalPosition);
        return;
      }
      await client.aboutToShow(0);
      final root = await client.layout();
      if (root == null || !context.mounted) return;
      if (root.visibleChildren.isEmpty) {
        // An empty exported menu: the application may draw its own.
        await manager.contextMenu(item.id, globalPosition);
        return;
      }
      menu.value = root;
      menuController.open();
      unawaited(client.event(0, 'opened'));
    }

    void onScroll(PointerSignalEvent event) {
      if (event is! PointerScrollEvent) return;
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        // A wheel notch is one step; a touchpad accumulates pixels.
        final isWheel = event.kind == PointerDeviceKind.mouse;
        final total = scrollRemainder.value + event.scrollDelta;
        int steps(double delta) => isWheel
            ? delta.sign.toInt()
            : (delta / _scrollStepPixels).truncate();
        final vertical = steps(total.dy);
        final horizontal = steps(total.dx);
        scrollRemainder.value = isWheel
            ? Offset.zero
            : Offset(
                total.dx - horizontal * _scrollStepPixels,
                total.dy - vertical * _scrollStepPixels,
              );
        // Positive is up and right, as with a wheel's angle delta.
        if (vertical != 0) {
          unawaited(manager.scroll(item.id, -vertical, 'vertical'));
        }
        if (horizontal != 0) {
          unawaited(manager.scroll(item.id, horizontal, 'horizontal'));
        }
      });
    }

    final toolTip = item.toolTip;
    final description = toolTip == null
        ? ''
        : plainToolTipText(toolTip.description);
    final title = toolTip != null && toolTip.title.isNotEmpty
        ? toolTip.title
        : item.label;
    final tooltipMessage = [
      title,
      if (description.isNotEmpty) description,
    ].join('\n');

    return MenuAnchor(
      controller: menuController,
      // On the root overlay so the status bar or the Helm does not clip it.
      useRootOverlay: true,
      onOpen: () => isOpen.value = true,
      onClose: () {
        isOpen.value = false;
        if (client != null) unawaited(client.event(0, 'closed'));
      },
      menuChildren: menu.value == null || client == null
          ? const []
          : _menuChildren(
              menu.value!,
              client,
              item,
              reloadMenu,
              (entryId) =>
                  unawaited(manager.menuEntryClicked(item.id, client, entryId)),
            ),
      child: Listener(
        onPointerSignal: onScroll,
        child: GestureDetector(
          onTertiaryTapUp: (details) => unawaited(
            manager.secondaryActivate(item.id, details.globalPosition),
          ),
          child: Tooltip(
            message: tooltipMessage,
            child: InkWell(
              borderRadius: BorderRadius.circular(iconSize),
              onTapUp: (details) async {
                if (item.itemIsMenu) {
                  await openMenu(details.globalPosition);
                  return;
                }
                final activated = await manager.activate(
                  item.id,
                  details.globalPosition,
                );
                if (!activated) await openMenu(details.globalPosition);
              },
              onTap: () {},
              onSecondaryTapUp: (details) =>
                  unawaited(openMenu(details.globalPosition)),
              child: Padding(
                padding: padding,
                child: Opacity(
                  opacity: item.status == TrayItemStatus.passive ? 0.6 : 1,
                  child: TrayItemIcon(item: item, size: iconSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The menu entries under [parent], as Material menu items.
List<Widget> _menuChildren(
  TrayMenuEntry parent,
  TrayMenuClient client,
  TrayItem item,
  Future<void> Function() reload,
  void Function(int entryId) onClicked,
) {
  return [
    for (final entry in parent.visibleChildren)
      if (entry.isSeparator)
        const Divider(height: 1)
      else if (entry.isSubmenu)
        SubmenuButton(
          onOpen: () async {
            unawaited(client.event(entry.id, 'opened'));
            if (await client.aboutToShow(entry.id)) await reload();
          },
          onClose: () => unawaited(client.event(entry.id, 'closed')),
          leadingIcon: _MenuEntryIcon(entry: entry, item: item),
          menuChildren: _menuChildren(entry, client, item, reload, onClicked),
          child: Text(entry.label),
        )
      else
        MenuItemButton(
          onPressed: entry.enabled ? () => onClicked(entry.id) : null,
          leadingIcon: _MenuEntryIcon(entry: entry, item: item),
          child: Text(entry.label),
        ),
  ];
}

/// The leading icon of a menu entry: its toggle, or its own icon. Every entry
/// of a menu with icons keeps the room for one, so labels stay aligned.
class _MenuEntryIcon extends StatelessWidget {
  const _MenuEntryIcon({required this.entry, required this.item});

  static const double size = 18;

  final TrayMenuEntry entry;
  final TrayItem item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.toggle) {
      TrayMenuToggle.checkmark => ShellIcon(
        entry.toggled ?? false
            ? MdiIcons.checkboxMarked
            : MdiIcons.checkboxBlankOutline,
        size: size,
      ),
      TrayMenuToggle.radio => ShellIcon(
        entry.toggled ?? false
            ? MdiIcons.radioboxMarked
            : MdiIcons.radioboxBlank,
        size: size,
      ),
      TrayMenuToggle.none when entry.iconData != null => Image.memory(
        entry.iconData!,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => const SizedBox.square(dimension: size),
      ),
      TrayMenuToggle.none when entry.iconName.isNotEmpty => TrayNamedIcon(
        name: entry.iconName,
        themePath: item.iconThemePath,
        size: size,
        fallback: const SizedBox.square(dimension: size),
      ),
      TrayMenuToggle.none => null,
    };
    return SizedBox.square(dimension: size, child: icon);
  }
}
