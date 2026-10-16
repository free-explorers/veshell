import 'package:material_ui/material_ui.dart';
import 'package:shell/theme/provider/theme.dart';

/// A rounded-square icon button used for the overview's search-mode switcher
/// and a dialog area's action strip.
///
/// Selected buttons are filled with the primary container so an active mode
/// reads at a glance; plain actions leave [isSelected] false. Shared so the
/// dialog actions sit at the same weight as the search-panel categories.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    required this.icon,
    required this.onSelected,
    this.isSelected = false,
    this.tooltip,
    super.key,
  });

  final bool isSelected;
  final Widget icon;
  final void Function()? onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    var buttonType = IconButton.new;
    var style = IconButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(surfaceRadius),
      ),
      padding: const EdgeInsets.all(12),
      iconSize: 28,
    );
    if (isSelected) {
      buttonType = IconButton.filled;
      style = style.copyWith(
        backgroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primaryContainer,
        ),
        foregroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      );
    }
    return buttonType(
      onPressed: onSelected,
      icon: icon,
      style: style,
      tooltip: tooltip,
    );
  }
}
