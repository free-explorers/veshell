import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/platform/widget/swipe_gesture_detector.dart';

class SlidingContainer extends HookConsumerWidget {
  const SlidingContainer({
    required this.children,
    required this.index,
    this.direction = Axis.horizontal,
    this.visible = 1,
    this.onIndexChanged,
    this.isSwipeEnabled = true,
    super.key,
  });
  final Axis direction;
  final List<Widget> children;
  final int index;
  final int visible;
  final bool isSwipeEnabled;
  final void Function(int newIndex)? onIndexChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController(
      initialPage: index,
      viewportFraction: 1.0 / visible,
      keys: [visible],
    );

    final swipeInProgress = useState(false);
    final lastSwipeTime = useState<int?>(null);
    final swipeVelocityTracker = useState<VelocityTracker?>(null);

    return LayoutBuilder(
      builder: (context, constraints) {
        return HookBuilder(
          builder: (context) {
            void scrollToIndex(int indexToScrollTo) {
              if (!pageController.hasClients) {
                return;
              }

              final viewportWidth = constraints.biggest.width;
              final viewportHeight = constraints.biggest.height;
              final pageWidth = direction == Axis.horizontal
                  ? viewportWidth / visible
                  : viewportWidth;
              final pageHeight = direction == Axis.horizontal
                  ? viewportHeight
                  : viewportHeight / visible;
              final firstPageInView = direction == Axis.horizontal
                  ? pageController.offset / pageWidth
                  : pageController.offset / pageHeight;
              final visibleRangeStart = firstPageInView;
              final visibleRangeEnd = firstPageInView + visible - 1;
              double? offset;
              // Depending on the direction calculate the minimal offset to animate
              if (indexToScrollTo < visibleRangeStart) {
                offset = direction == Axis.horizontal
                    ? pageWidth * indexToScrollTo
                    : pageHeight * indexToScrollTo;
              } else if (indexToScrollTo > visibleRangeEnd) {
                offset = direction == Axis.horizontal
                    ? pageWidth * (indexToScrollTo - visible + 1)
                    : pageHeight * (indexToScrollTo - visible + 1);
              }
              if (offset != null) {
                pageController.animateTo(
                  offset,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                );
              }
            }

            useEffect(
              () {
                scrollToIndex(index);
                return null;
              },
              [index, children],
            );
            return SwipeGestureDetector(
              enabled: isSwipeEnabled,
              onSwipeUpdate: (event) {
                if (event.message.fingers != 3) {
                  return;
                }
                // Determine the direction of the swipe (horizontal or vertical
                final eventDirection =
                    event.message.deltaX.abs() > event.message.deltaY.abs()
                        ? Axis.horizontal
                        : Axis.vertical;

                if (eventDirection != direction) {
                  return;
                }
                if (!swipeInProgress.value) {
                  swipeInProgress.value = true;
                  swipeVelocityTracker.value =
                      VelocityTracker.withKind(PointerDeviceKind.trackpad);
                }

                final delta = direction == Axis.horizontal
                    ? event.message.deltaX
                    : event.message.deltaY;

                final position =
                    pageController.position as ScrollPositionWithSingleContext;
                position.pointerScroll(delta);
                if (lastSwipeTime.value != null) {
                  swipeVelocityTracker.value?.addPosition(
                    Duration(
                      milliseconds: event.message.time - lastSwipeTime.value!,
                    ),
                    direction == Axis.horizontal
                        ? Offset(delta, 0)
                        : Offset(0, delta),
                  );
                }
                lastSwipeTime.value = event.message.time;
              },
              onSwipeEnd: (event) {
                if (swipeInProgress.value) {
                  swipeInProgress.value = false;
                  final velocity = swipeVelocityTracker.value?.getVelocity();
                  swipeVelocityTracker.value = null;
                  const physics = BouncingScrollPhysics(
                    decelerationRate: ScrollDecelerationRate.fast,
                    parent: RangeMaintainingScrollPhysics(),
                  );
                  final simulation = physics.createBallisticSimulation(
                    pageController.position,
                    direction == Axis.horizontal
                        ? velocity!.pixelsPerSecond.dx
                        : velocity!.pixelsPerSecond.dy,
                  );
                  var target = pageController.offset;
                  if (simulation != null) {
                    target = simulation.x(1);
                  }
                  final viewportWidth = constraints.biggest.width;
                  final viewportHeight = constraints.biggest.height;
                  final pageWidth = direction == Axis.horizontal
                      ? viewportWidth / visible
                      : viewportWidth;
                  final pageHeight = direction == Axis.horizontal
                      ? viewportHeight
                      : viewportHeight / visible;
                  final pageSize =
                      direction == Axis.horizontal ? pageWidth : pageHeight;
                  final targetPage = target / pageSize;
                  if (targetPage < index) {
                    onIndexChanged?.call(index - 1);
                  } else if (targetPage > index) {
                    onIndexChanged?.call(index + 1);
                  } else {
                    scrollToIndex(index);
                  }
                }
              },
              child: PageView.builder(
                controller: pageController,
                scrollDirection: direction,
                itemCount: children.length,
                itemBuilder: (context, index) {
                  return children[index];
                },
                physics: const NeverScrollableScrollPhysics(),
                pageSnapping: false,
                padEnds: false,
              ),
            );
          },
        );
      },
    );
  }
}
