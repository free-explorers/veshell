import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/system_tray/provider/system_tray_manager.dart';
import 'package:shell/system_tray/widget/tray_item_button.dart';

/// The width of one tray item in the card: its icon and a short label.
const _itemWidth = 80.0;

/// The system tray card, or `null` when no application has a tray item.
///
/// The card lists every item, passive ones included (dimmed), with its name,
/// so the Helm is where the whole tray is always reachable, whatever the
/// status bar shows.
Widget? systemTraySection(WidgetRef ref) {
  final items = ref.watch(systemTrayManagerProvider);
  if (items.isEmpty) return null;
  return Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SystemTrayHeader(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final item in items)
                SizedBox(
                  width: _itemWidth,
                  child: TrayItemButton(
                    key: ValueKey(item.id),
                    item: item,
                    iconSize: 32,
                    padding: const EdgeInsets.all(8),
                    label: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SystemTrayHeader extends StatelessWidget {
  const _SystemTrayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox.square(
          dimension: 24,
          child: ShellIcon(
            MdiIcons.dotsHorizontal,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            context.l10n.systemTray,
            style: theme.textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
