import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class Expandable extends HookConsumerWidget {
  const Expandable({
    required this.collapsed,
    required this.expanded,
    this.isExpanded = false,
    super.key,
  });

  /// Whe widget to show when collapsed
  final Widget collapsed;

  /// The widget to show when expanded
  final Widget expanded;

  final bool isExpanded;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedCrossFade(
      firstChild: collapsed,
      secondChild: expanded,
      crossFadeState:
          isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
      firstCurve: Curves.easeOut,
      secondCurve: Curves.easeOut,
      sizeCurve: Curves.easeOut,
    );
  }
}
