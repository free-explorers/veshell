import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SlidingContainer extends HookConsumerWidget {
  const SlidingContainer({
    required this.children,
    required this.index,
    this.direction = Axis.horizontal,
    this.visible = 1,
    super.key,
  });
  final Axis direction;
  final List<Widget> children;
  final int index;
  final int visible;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController =
        usePageController(initialPage: index, viewportFraction: 1.0 / visible);
    useEffect(
      () {
        if (pageController.hasClients) {
          pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
        return null;
      },
      [index],
    );
    return PageView(
      controller: pageController,
      scrollDirection: direction,
      children: children,
    );
  }
}
