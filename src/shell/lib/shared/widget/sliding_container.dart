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
    this.selectionIndicator,
    this.viewportMetaData,
    this.buildsNeighbors = false,
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

  /// Bars drawn on both sides of the selected page, across [direction], that
  /// slide to the newly selected page instead of jumping. `null` hides them
  /// and removes the gap they live in.
  final SlidingSelectionIndicator? selectionIndicator;

  /// Builds a `MetaData` value attached to the page viewport, given the
  /// viewport's current scroll offset, so a hit test can map a position to a
  /// page.
  final Object Function(double Function() scrollOffset)? viewportMetaData;

  /// Keeps a viewport's worth of pages built on each side of the visible ones,
  /// so a page sliding in from off screen is already there.
  final bool buildsNeighbors;
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

    // The selected position as a fractional page index, eased between pages
    // with the same timing as the scroll so the indicator glides along.
    final selectionPosition = useAnimationController(
      duration: const Duration(milliseconds: 200),
      lowerBound: double.negativeInfinity,
      upperBound: double.infinity,
      initialValue: index.toDouble(),
    );
    useEffect(() {
      selectionPosition.animateTo(index.toDouble(), curve: Curves.easeInOut);
      return null;
    }, [index]);

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
              // The indicator fills a gap of its own thickness on both
              // cross-axis sides. The
              // widget structure stays the same with or without it (only the
              // gap and the painting change) so toggling it never remounts
              // the pages.
              final gap = selectionIndicator?.thickness ?? 0;
              final crossAxisExtent =
                  (isHorizontal
                      ? constraints.maxHeight
                      : constraints.maxWidth) -
                  2 * gap;
              return Align(
                alignment: isHorizontal
                    ? Alignment.centerLeft
                    : Alignment.topCenter,
                child: CustomPaint(
                  foregroundPainter: _SelectionIndicatorPainter(
                    indicator: selectionIndicator,
                    position: selectionPosition,
                    pageController: pageController,
                    pageExtent: pageViewport / visible,
                    direction: direction,
                  ),
                  child: Padding(
                    padding: isHorizontal
                        ? EdgeInsets.symmetric(vertical: gap)
                        : EdgeInsets.symmetric(horizontal: gap),
                    child: MetaData(
                      metaData: viewportMetaData?.call(
                        () =>
                            pageController.hasClients &&
                                pageController.position.hasPixels
                            ? pageController.offset
                            : 0,
                      ),
                      behavior: HitTestBehavior.translucent,
                      child: SizedBox(
                        width: isHorizontal ? pageViewport : crossAxisExtent,
                        height: isHorizontal ? crossAxisExtent : pageViewport,
                        child: PageView.builder(
                          controller: pageController,
                          scrollDirection: direction,
                          itemCount: children.length,
                          itemBuilder: (context, index) {
                            return children[index];
                          },
                          // A keyed page keeps its state when it moves to
                          // another index, instead of the page now at its old
                          // index taking that state over.
                          findChildIndexCallback: (key) {
                            final index = children.indexWhere(
                              (child) => child.key == key,
                            );
                            return index < 0 ? null : index;
                          },
                          allowImplicitScrolling: buildsNeighbors,
                          physics: const NeverScrollableScrollPhysics(),
                          pageSnapping: false,
                          padEnds: false,
                        ),
                      ),
                    ),
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

/// Appearance of the [SlidingContainer] selection indicator.
@immutable
class SlidingSelectionIndicator {
  const SlidingSelectionIndicator({required this.color, this.thickness = 3});

  final Color color;

  /// Width of each bar across the sliding axis, which is also the gap kept
  /// free for it on each cross-axis side of the pages. Along the sliding axis
  /// a bar spans its whole page.
  final double thickness;

  @override
  bool operator ==(Object other) =>
      other is SlidingSelectionIndicator &&
      other.color == color &&
      other.thickness == thickness;

  @override
  int get hashCode => Object.hash(color, thickness);
}

class _SelectionIndicatorPainter extends CustomPainter {
  _SelectionIndicatorPainter({
    required this.indicator,
    required this.position,
    required this.pageController,
    required this.pageExtent,
    required this.direction,
  }) : super(repaint: Listenable.merge([position, pageController]));

  final SlidingSelectionIndicator? indicator;
  final Animation<double> position;
  final PageController pageController;
  final double pageExtent;
  final Axis direction;

  @override
  void paint(Canvas canvas, Size size) {
    final indicator = this.indicator;
    if (indicator == null || pageExtent <= 0) {
      return;
    }
    final scrollOffset =
        pageController.hasClients && pageController.position.hasPixels
        ? pageController.offset
        : 0.0;
    final start = position.value * pageExtent - scrollOffset;
    final end = start + pageExtent;
    final isHorizontal = direction == Axis.horizontal;
    final crossExtent = isHorizontal ? size.height : size.width;
    final thickness = indicator.thickness;
    final paint = Paint()..color = indicator.color;

    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    for (final cross in [0.0, crossExtent - thickness]) {
      final rect = isHorizontal
          ? Rect.fromLTRB(start, cross, end, cross + thickness)
          : Rect.fromLTRB(cross, start, cross + thickness, end);
      canvas.drawRect(rect, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SelectionIndicatorPainter oldDelegate) =>
      indicator != oldDelegate.indicator ||
      position != oldDelegate.position ||
      pageController != oldDelegate.pageController ||
      pageExtent != oldDelegate.pageExtent ||
      direction != oldDelegate.direction;
}
