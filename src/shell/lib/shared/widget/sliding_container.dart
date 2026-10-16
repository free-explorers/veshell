import 'package:flutter/gestures.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/platform/widget/swipe_gesture_detector.dart';
import 'package:shell/shared/util/snapping.dart';

const swipeVelocityThreshold = 800;

class SlidingContainer extends HookConsumerWidget {
  const SlidingContainer({
    required this.children,
    required this.index,
    this.direction = Axis.horizontal,
    this.visible = 1,
    this.firstVisibleIndex,
    this.onIndexChanged,
    this.onFirstVisibleIndexChanged,
    this.isSwipeEnabled = true,
    super.key,
  });
  final Axis direction;
  final List<Widget> children;
  final int index;
  final int visible;
  final bool isSwipeEnabled;
  final void Function(int newIndex)? onIndexChanged;

  /// The leading (leftmost/topmost) tile to restore when the container is
  /// created. Falls back to [index] when omitted, which anchors the selected
  /// tile at the leading edge.
  final int? firstVisibleIndex;

  /// Called after the frame whenever the leading tile shown by the container
  /// settles on a new index, so callers can persist it and restore the exact
  /// same view when the container is rebuilt.
  final void Function(int newFirstVisibleIndex)? onFirstVisibleIndexChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the leading tile up front: the effect below runs during the build
    // that mounts the `PageView`, before it has a scroll position, so it cannot
    // perform the initial scroll. If the selected tile falls outside the
    // restored view, shift the view just enough to include it.
    final initialPage = _resolveInitialPage();
    final pageController = usePageController(
      initialPage: initialPage,
      viewportFraction: 1.0 / visible,
      keys: [visible],
    );

    final swipeInProgress = useState(false);
    final cumulatedSwipeDelta = useState<double>(0);
    final swipeVelocityTracker = useState<VelocityTracker?>(null);
    final reportedFirstVisibleIndex = useRef<int?>(null);

    void reportFirstVisibleIndex(int newFirstVisibleIndex) {
      final clamped = newFirstVisibleIndex.clamp(0, children.length - 1);
      if (reportedFirstVisibleIndex.value == clamped) {
        return;
      }
      reportedFirstVisibleIndex.value = clamped;
      // Reporting runs from a build-time effect, so notify after the frame;
      // mutating the caller's state mid-build is not allowed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        onFirstVisibleIndexChanged?.call(clamped);
      });
    }

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
          reportFirstVisibleIndex(
            offset == null
                ? firstPageInView.round()
                : (offset / pageDimension).round(),
          );
          if (offset != null) {
            pageController.animateTo(
              offset,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          }
        }

        useEffect(() {
          if (pageController.hasClients) {
            scrollToIndex(index);
          } else {
            // The mounting build has no scroll position yet; the initial page
            // already encodes the restored view, so persist that.
            reportFirstVisibleIndex(initialPage);
          }
          return null;
        }, [index, children]);
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
              swipeVelocityTracker.value = VelocityTracker.withKind(
                PointerDeviceKind.trackpad,
              );
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
              Duration(milliseconds: event.message.time),
              direction == Axis.horizontal
                  ? Offset(cumulatedSwipeDelta.value, 0)
                  : Offset(0, cumulatedSwipeDelta.value),
            );
          },
          onSwipeEnd: (event) {
            if (swipeInProgress.value) {
              swipeInProgress.value = false;
              final velocity = direction == Axis.horizontal
                  ? swipeVelocityTracker.value
                            ?.getVelocity()
                            .pixelsPerSecond
                            .dx ??
                        0
                  : swipeVelocityTracker.value
                            ?.getVelocity()
                            .pixelsPerSecond
                            .dy ??
                        0;
              swipeVelocityTracker.value = null;
              final target = pageController.offset;
              final viewportDimension =
                  pageController.position.viewportDimension;
              final pageDimension = viewportDimension / visible;
              final viewportCenter = target + (viewportDimension / 2);
              final targetPage = (viewportCenter / pageDimension).floor();
              if (targetPage < index ||
                  (velocity < -swipeVelocityThreshold && index > 0)) {
                onIndexChanged?.call(index - 1);
              } else if (targetPage > index ||
                  (velocity > swipeVelocityThreshold &&
                      index < children.length - 1)) {
                onIndexChanged?.call(index + 1);
              } else {
                scrollToIndex(index);
              }
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Snap the page viewport to a whole number of whole-pixel pages.
              // A live Wayland surface is an external Flutter `Texture` sampled
              // bilinearly (`FilterQuality.low`), so a fractional page origin
              // softens every window on it. `viewport / visible` is fractional
              // whenever the viewport is not divisible by the visible count
              // (e.g. `2464 / 3`), which put the second and later tiles off the
              // pixel grid. Keeping the viewport a whole multiple of the page
              // leaves at most `visible - 1` pixels unused at the trailing
              // edge; the scroll math reads the controller's viewport, so it
              // follows the snapped extent automatically.
              final isHorizontal = direction == Axis.horizontal;
              final mainAxisExtent = isHorizontal
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              final pageViewport = snapPageViewport(mainAxisExtent, visible);
              return Align(
                alignment: isHorizontal
                    ? Alignment.centerLeft
                    : Alignment.topCenter,
                child: SizedBox(
                  width: isHorizontal ? pageViewport : constraints.maxWidth,
                  height: isHorizontal ? constraints.maxHeight : pageViewport,
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// The leading tile the container should start on.
  ///
  /// Prefers [firstVisibleIndex] (the restored view) and, when [index] would
  /// fall outside it, shifts by the minimal amount needed to bring the selected
  /// tile back into view. With no restored view it falls back to anchoring the
  /// selected tile at the leading edge, which preserves the previous behavior.
  int _resolveInitialPage() {
    if (children.isEmpty) {
      return 0;
    }
    final maxLeading = (children.length - visible).clamp(
      0,
      children.length - 1,
    );
    var leading = (firstVisibleIndex ?? index).clamp(0, maxLeading);
    if (index < leading) {
      leading = index;
    } else if (index > leading + visible - 1) {
      leading = index - visible + 1;
    }
    return leading.clamp(0, maxLeading);
  }
}
