import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/file_explorer/widget/file_entry_icon.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/model/overview_content.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';

/// The panel tab for a single [OverviewContent].
///
/// This is the only place that maps a content kind to its tab, so a new
/// [OverviewContent] variant fails to compile until it is handled here.
class OverviewContentTab extends StatelessWidget {
  const OverviewContentTab({
    required this.content,
    required this.isSelected,
    required this.onSelect,
    required this.onClose,
    super.key,
  });

  final OverviewContent content;
  final bool isSelected;
  final VoidCallback onSelect;

  /// Removes the content from the panel. Windows ignore it and close through
  /// their own provider, so their teardown stays complete.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return switch (content) {
      HelmOverviewContent() => _OverviewPanelTab(
        icon: const Icon(MdiIcons.shipWheel),
        label: context.l10n.helm,
        isSelected: isSelected,
        onTap: onSelect,
      ),
      WindowOverviewContent(:final windowId) => _WindowContentTab(
        windowId: windowId,
        isSelected: isSelected,
        onTap: onSelect,
      ),
      PreviewOverviewContent(:final entry) => _OverviewPanelTab(
        icon: Icon(iconForFileEntry(entry)),
        label: entry.name,
        isSelected: isSelected,
        onTap: onSelect,
        trailingBuilder: (foregroundColor) =>
            _CloseButton(color: foregroundColor, onPressed: onClose),
      ),
    };
  }
}

class _WindowContentTab extends ConsumerWidget {
  const _WindowContentTab({
    required this.windowId,
    required this.isSelected,
    required this.onTap,
  });

  final EphemeralWindowId windowId;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(ephemeralWindowStateProvider(windowId));
    final appId = window.properties.appId;
    final entry = ref.watch(localizedDesktopEntryForIdProvider(appId)).value;
    final label =
        entry?.entries[DesktopEntryKey.name.string] ??
        window.properties.title ??
        context.l10n.unknown;

    return _OverviewPanelTab(
      icon: Padding(
        padding: const EdgeInsets.all(4),
        child: AppIconById(id: appId),
      ),
      label: label,
      isSelected: isSelected,
      onTap: onTap,
      trailingBuilder: (foregroundColor) => _CloseButton(
        color: foregroundColor,
        onPressed: () {
          ref
              .read(ephemeralWindowStateProvider(windowId).notifier)
              .closeWindow();
        },
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      color: color,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: const Icon(MdiIcons.close, size: 16),
    );
  }
}

/// A pill-shaped tab of the overview content panel: an icon, a label and an
/// optional trailing action. Only the selected tab is tinted, and the
/// foreground is handed to [trailingBuilder] so the trailing action matches.
class _OverviewPanelTab extends StatelessWidget {
  const _OverviewPanelTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.trailingBuilder,
  });

  final Widget icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget Function(Color foregroundColor)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foregroundColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Material(
      borderRadius: BorderRadius.circular(24),
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: 32, child: icon),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (trailingBuilder != null) ...[
                const SizedBox(width: 4),
                trailingBuilder!(foregroundColor),
              ],
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
