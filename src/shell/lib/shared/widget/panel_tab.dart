import 'package:material_ui/material_ui.dart';

/// A pill-shaped tab of a content panel: an icon, a label and an optional
/// trailing action. Only the selected tab is tinted, and the foreground is
/// handed to [trailingBuilder] so the trailing action matches.
///
/// Shared by the overview's content panel and a tile's dialog area so both
/// read the same. Kept free of feature imports: the caller supplies the icon
/// and (localized) label.
class PanelTab extends StatelessWidget {
  const PanelTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.trailingBuilder,
    super.key,
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
