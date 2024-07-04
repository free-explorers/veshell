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
    final pageController = usePageController(
      initialPage: index,
      viewportFraction: 1.0 / visible,
      keys: [visible],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return HookBuilder(
          builder: (context) {
            useEffect(
              () {
                if (pageController.hasClients) {
                  final viewportWidth = constraints.biggest.width;
                  final viewportHeight = constraints.biggest.height;
                  final pageWidth = direction == Axis.horizontal
                      ? viewportWidth / visible
                      : viewportWidth;
                  final pageHeight = direction == Axis.horizontal
                      ? viewportHeight
                      : viewportHeight / visible;
                  final currentPage = direction == Axis.horizontal
                      ? pageController.offset / pageWidth
                      : pageController.offset / pageHeight;
                  final visibleRangeStart = currentPage;
                  final visibleRangeEnd = currentPage + visible - 1;
                  double? offset;
                  // Depending on the direction calculate the minimal offset to animate
                  if (index < visibleRangeStart) {
                    offset = direction == Axis.horizontal
                        ? pageWidth * index
                        : pageHeight * index;
                  } else if (index > visibleRangeEnd) {
                    offset = direction == Axis.horizontal
                        ? pageWidth * (index - visible + 1)
                        : pageHeight * (index - visible + 1);
                  }
                  if (offset != null) {
                    pageController.animateTo(
                      offset,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                    );
                  }
                }
                return null;
              },
              [index, children],
            );
            return PageView.builder(
              controller: pageController,
              scrollDirection: direction,
              itemCount: children.length,
              itemBuilder: (context, index) {
                return children[index];
              },
              physics: const NeverScrollableScrollPhysics(),
              pageSnapping: false,
              padEnds: false,
            );
          },
        );
      },
    );
  }
}
