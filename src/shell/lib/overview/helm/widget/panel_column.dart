import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Vertical gap between the cards of a panel column, and between the panel
/// columns themselves.
const panelGap = 8.0;

/// A group of cards contributed to a [PanelColumn].
///
/// Return `null` when the group has nothing to show, so the column does not
/// reserve an empty slot (and its spacing) for it.
typedef PanelSection = Widget? Function(WidgetRef ref);

/// A vertically scrollable column of cards with an optional pinned [footer].
///
/// The cards are spaced by [panelGap]. A section that groups several cards
/// returns a nested [Column] with the same spacing, so the gaps stay uniform
/// whether a card stands alone or inside a group.
class PanelColumn extends ConsumerWidget {
  const PanelColumn({required this.sections, this.footer, super.key});

  final List<PanelSection> sections;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final footer = this.footer;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: panelGap,
              children: [for (final section in sections) ?section(ref)],
            ),
          ),
        ),
        if (footer != null) ...[
          const Divider(height: 2),
          const SizedBox(height: panelGap),
          footer,
        ],
      ],
    );
  }
}
