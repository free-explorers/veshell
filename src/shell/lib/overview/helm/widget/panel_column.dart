import 'package:material_ui/material_ui.dart';

/// A vertically scrollable column of cards with an optional pinned [footer].
///
/// The body scrolls so the panels keep working on short screens, while widgets
/// such as the session controls stay reachable at the bottom.
class PanelColumn extends StatelessWidget {
  const PanelColumn({required this.children, this.footer, super.key});

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return Column(
      children: [
        Expanded(child: ListView(children: children)),
        if (footer != null) ...[
          const Divider(height: 2),
          const SizedBox(height: 8),
          footer,
        ],
      ],
    );
  }
}
