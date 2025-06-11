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
    final cumulatedSwipeDelta = useState<double>(0);
    final swipeVelocityTracker = useState<VelocityTracker?>(null);

    return HookBuilder(
      builder: (context) {
        void scrollToIndex(int indexToScrollTo) {
          if (!pageController.hasClients) {
            return;
          }
          final viewportDimension = pageController.position.viewportDimension;
          final pageDimension = viewportDimension / visible;
          final firstPageInView = pageController.offset / pageDimension;
          final visibleRangeStart = firstPageInView;
          final visibleRangeEnd = firstPageInView + visible - 1;
          double? offset;
          // Depending on the direction calculate the minimal offset to animate
          if (indexToScrollTo < visibleRangeStart) {
            offset = pageDimension * indexToScrollTo;
          } else if (indexToScrollTo > visibleRangeEnd) {
            offset = pageDimension * (indexToScrollTo - visible + 1);
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
              cumulatedSwipeDelta.value = 0;
            }

            final delta = direction == Axis.horizontal
                ? event.message.deltaX
                : event.message.deltaY;
            cumulatedSwipeDelta.value += delta;
            final position =
                pageController.position as ScrollPositionWithSingleContext;
            position.pointerScroll(delta);
            swipeVelocityTracker.value?.addPosition(
              Duration(
                milliseconds: event.message.time,
              ),
              direction == Axis.horizontal
                  ? Offset(cumulatedSwipeDelta.value, 0)
                  : Offset(0, cumulatedSwipeDelta.value),
            );
          },
          onSwipeEnd: (event) {
            if (swipeInProgress.value) {
              swipeInProgress.value = false;
              final velocityEstimate =
                  swipeVelocityTracker.value?.getVelocityEstimate();
              swipeVelocityTracker.value = null;
              final target = pageController.offset;
              final viewportDimension =
                  pageController.position.viewportDimension;
              final pageDimension = viewportDimension / visible;
              final viewportCenter = target + (viewportDimension / 2);
              final targetPage = (viewportCenter / pageDimension).floor();
              final velocity = direction == Axis.horizontal
                  ? velocityEstimate!.pixelsPerSecond.dx
                  : velocityEstimate!.pixelsPerSecond.dy;
              if (targetPage < index || (velocity < -1000 && index > 0)) {
                onIndexChanged?.call(index - 1);
              } else if (targetPage > index ||
                  (velocity > 1000 && index < children.length - 1)) {
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
  }
}
