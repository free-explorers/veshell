import 'dart:math' as math;
import 'dart:ui' show clampDouble, lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/platform/provider/swipe_gesture_arbiter.dart';
import 'package:shell/platform/widget/swipe_gesture_detector.dart';
import 'package:shell/shared/provider/cursor_transition.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/util/snapping.dart';

/// Gesture travel for one full horizontal page, in the compositor's
/// normalized swipe units (1000 dpi, so ~39 units per mm). GNOME Shell uses
/// the same 400-unit touchpad base, which is about 10 mm of finger movement
/// and makes a full-width tile reachable with a normal horizontal swipe.
const _horizontalPageSwipe = 400.0;

/// Gesture travel for one full vertical page (~7.6 mm), matching GNOME
/// Shell's touchpad base height and the workspace swipe of Hyprland and Niri.
const _verticalPageSwipe = 300.0;

/// Fling speed below which a release snaps to the nearest page instead of
/// projecting. 0.6 normalized units per millisecond, like GNOME Shell.
const _flingThreshold = 600.0;

/// Time constant of the touchpad fling deceleration (0.997 per millisecond),
/// as used by GNOME Shell and Niri. The end position is
/// `progress + velocity * _decelerationTime`.
const _decelerationTime = 0.333;

/// Duration of a settling animation, from the remaining distance and the
/// release speed. GNOME Shell uses `remaining / velocity * 3`, clamped to
/// 100–400 ms, so a fast flick lands quickly and a slow drag glides longer.
Duration _settleDuration(double remainingPages, double velocity) {
  if (velocity <= 0 || remainingPages <= 0) {
    return const Duration(milliseconds: 200);
  }
  final milliseconds = remainingPages / velocity * 1000 * 3;
  return Duration(
    milliseconds: math.min(400, math.max(100, milliseconds.round())),
  );
}

/// How long the row takes to resize into a new page count.
const _resizeDuration = Duration(milliseconds: 120);

/// Sums the gesture deltas of the last 150 ms to estimate the release
/// velocity, like GNOME Shell and Niri. The short window lets a pause before
/// lifting the fingers decay the fling instead of keeping the speed of a
/// movement that ended long ago.
class _SwipeHistory {
  static const _windowMs = 150;

  final _samples = <(int, double)>[];

  void reset() => _samples.clear();

  void append(int timeMs, double delta) {
    if (_samples.isNotEmpty && timeMs < _samples.last.$1) {
      return;
    }
    trim(timeMs);
    _samples.add((timeMs, delta));
  }

  void trim(int timeMs) {
    final oldest = timeMs - _windowMs;
    while (_samples.isNotEmpty && _samples.first.$1 < oldest) {
      _samples.removeAt(0);
    }
  }

  /// Closes the gesture at [timeMs] and returns its release velocity.
  ///
  /// The zero sample lets a pause before lifting the fingers decay the fling,
  /// and the history is reset for the next gesture.
  double finish(int timeMs) {
    append(timeMs, 0);
    trim(timeMs);
    final result = velocity();
    reset();
    return result;
  }

  /// Page fractions per second, over the samples still in the window.
  double velocity() {
    if (_samples.length < 2) {
      return 0;
    }
    final first = _samples.first.$1;
    final last = _samples.last.$1;
    if (last <= first) {
      return 0;
    }
    final delta = _samples
        .skip(1)
        .fold<double>(0, (sum, sample) => sum + sample.$2);
    return delta * 1000 / (last - first);
  }
}

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
    // A page leaving the hit test reports the arrow while it is still painted
    // under the pointer. Hold the cursor for the duration of this container's
    // slide so it does not blink on every navigation.
    final transitionToken = useMemoized(Object.new);
    final cursorTransition = ref.read(cursorTransitionProvider.notifier);
    useEffect(() {
      return () => cursorTransition.end(transitionToken);
    }, [cursorTransition, transitionToken]);

    // Resolve the leading tile up front: the effect below runs during the build
    // that mounts the `PageView`, before it has a scroll position, so it cannot
    // perform the initial scroll. If the selected tile falls outside the
    // restored view, shift the view just enough to include it.
    // The controller must survive a change of the page count: its offset is
    // part of the resize animation, and recreating it would reset the view to
    // the new layout at once. The page fraction passed to the row is animated
    // separately, so the controller's own `viewportFraction` is only the one
    // the row was mounted with.
    final initialPage = _resolveInitialPage();
    final pageController = usePageController(
      initialPage: initialPage,
      viewportFraction: 1.0 / visible,
    );

    final swipeInProgress = useState(false);
    // Set as soon as a gesture is recognised, before it has moved: the pages
    // about to slide in are built during that first frame instead of in the
    // middle of the animation, where the build would drop a frame.
    final swipePending = useState(false);
    // The continuous page progress of the gesture and the speed of its last
    // 150 ms, both in page fractions (the swipe is normalized to a fixed
    // finger distance, not to the page size).
    final swipeHistory = useRef(_SwipeHistory());
    // Where the row was when the current gesture began. The end of the
    // gesture turns the travel into a direction instead of guessing it from
    // the page the viewport centre happens to sit on.
    final swipeStartOffset = useRef<double?>(null);
    // Release speed and target of a swipe navigation, consumed by the
    // `scrollToIndex` effect that follows `onIndexChanged`. It turns the
    // settle animation into a velocity-aware one.
    final swipeSettleVelocity = useRef<double?>(null);
    final swipeSettleIndex = useRef<int?>(null);
    // Identifies this container to the shared gesture arbiter.
    final swipeToken = useMemoized(Object.new);
    final swipeArbiter = ref.read(swipeGestureArbiterProvider);
    final reportedFirstVisibleIndex = useRef<int?>(null);

    // The detector stops listening while disabled, so a gesture in progress
    // never delivers its end here. A stale `swipeInProgress` makes
    // `scrollToIndex` refuse to settle later selections, which leaves the row
    // stuck between two pages.
    useEffect(() {
      if (isSwipeEnabled) {
        return null;
      }
      swipeInProgress.value = false;
      swipeStartOffset.value = null;
      swipeHistory.value.reset();
      return null;
    }, [isSwipeEnabled]);

    // The selected position as a fractional page index, eased between pages
    // with the same timing as the scroll so the indicator glides along.
    final selectionPosition = useAnimationController(
      duration: const Duration(milliseconds: 200),
      lowerBound: double.negativeInfinity,
      upperBound: double.infinity,
      initialValue: index.toDouble(),
    );

    /// The size of one page along the scroll axis, `null` while the row has
    /// no laid-out scroll position.
    double? pageDimension() {
      if (!pageController.hasClients ||
          !pageController.position.hasPixels ||
          !pageController.position.hasViewportDimension) {
        return null;
      }
      final dimension = pageController.position.viewportDimension / visible;
      return dimension > 0 ? dimension : null;
    }

    // Finger travel, in normalized gesture units, that moves the row one page.
    final pageSwipe = direction == Axis.horizontal
        ? _horizontalPageSwipe
        : _verticalPageSwipe;

    // The caller moved the leading tile itself, not to follow this container's
    // report: the pages before the view changed (a tile before it was
    // removed), so the shown pages now sit at other indices. The view and the
    // indicator jump with them, and what is on screen does not move.
    final firstVisibleIndex = this.firstVisibleIndex;
    final seenFirstVisibleIndex = useRef(firstVisibleIndex);
    final previousFirstVisibleIndex = seenFirstVisibleIndex.value;
    seenFirstVisibleIndex.value = firstVisibleIndex;
    if (firstVisibleIndex != null &&
        previousFirstVisibleIndex != null &&
        firstVisibleIndex != previousFirstVisibleIndex &&
        firstVisibleIndex != reportedFirstVisibleIndex.value) {
      final shift = previousFirstVisibleIndex - firstVisibleIndex;
      // The selection is an index too: it moves with the pages right away.
      selectionPosition.value -= shift;
      final dimension = pageDimension();
      if (dimension != null) {
        if (!pageController.position.isScrollingNotifier.value) {
          // At rest or between two swipe updates: an integer shift keeps the
          // row's place between pages, and the gesture's origin moves with
          // it so its progress is still measured from the same tile.
          pageController.position.correctPixels(
            pageController.offset - shift * dimension,
          );
          final start = swipeStartOffset.value;
          if (start != null) {
            swipeStartOffset.value = start - shift * dimension;
          }
          reportedFirstVisibleIndex.value = firstVisibleIndex;
        } else {
          // A running animation would undo the correction on its next tick.
          // The new children make `scrollToIndex` retarget it in the new
          // indices; forget the stale report so the place the row lands on
          // is reported again, even when it has the old number.
          reportedFirstVisibleIndex.value = null;
        }
      }
    }

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
        // A newer report replaced this one before the frame ended. Applying
        // the stale leading index would make the correction above shift the
        // row while it is still scrolling, leaving it between two pages.
        if (reportedFirstVisibleIndex.value != clamped) return;
        onFirstVisibleIndexChanged?.call(clamped);
      });
    }

    return HookBuilder(
      builder: (context) {
        // The page count changed: the row's page fraction and scroll offset
        // are animated together, so tiles are laid out at every intermediate
        // size instead of being painted scaled (text and surfaces stay sharp).
        // The offset follows the leading tile, which keeps the current view in
        // place: a tile entering from off screen slides in while it shrinks,
        // and a tile leaving grows out of view.
        final resizeController = useAnimationController(
          duration: _resizeDuration,
        );
        final resizeTransition = useRef<_TileResize?>(null);
        final resizePending = useRef(false);
        final shownVisible = useRef(visible);
        final shownExtent = useRef<double?>(null);
        final resizeGeneration = useState(0);

        useEffect(() {
          void onStatus(AnimationStatus status) {
            if (status != AnimationStatus.completed) {
              return;
            }
            // The last tick and its rebuild can straddle the completion
            // callback; land the offset on the transition's target before the
            // transition is dropped from the tree.
            final transition = resizeTransition.value;
            if (transition != null && pageController.hasClients) {
              pageController.position.correctPixels(transition.toOffset);
            }
            // Drop the transition and turn the viewport's extra cache back
            // off.
            resizeTransition.value = null;
            resizeGeneration.value++;
          }

          resizeController.addStatusListener(onStatus);
          return () => resizeController.removeStatusListener(onStatus);
        }, [resizeController, pageController]);

        /// How far the page count transition has gone, eased like the row.
        double resizeProgress() {
          if (resizePending.value) {
            return 0;
          }
          if (resizeTransition.value == null) {
            return 1;
          }
          return Curves.easeInOut.transform(
            resizeController.value.clamp(0.0, 1.0),
          );
        }

        void scrollToIndex(int indexToScrollTo) {
          // A swipe navigation leaves its release speed for this effect. Take
          // it whether or not the target needs an animation, so it cannot leak
          // into a later keyboard navigation.
          final pendingVelocity = swipeSettleVelocity.value;
          final pendingIndex = swipeSettleIndex.value;
          swipeSettleVelocity.value = null;
          swipeSettleIndex.value = null;

          final dimension = pageDimension();
          if (dimension == null) {
            return;
          }
          final firstPageInView = pageController.offset / dimension;
          double? target;
          // Depending on the direction calculate the minimal offset to animate
          if (indexToScrollTo < firstPageInView) {
            target = dimension * indexToScrollTo;
          } else if (indexToScrollTo > firstPageInView + visible - 1) {
            target = dimension * (indexToScrollTo - visible + 1);
          } else {
            // The selected page is already visible, but a swipe can leave the
            // row between two slots: with more than one visible tile the
            // selection can settle without the scroll position moving, so
            // this branch is the only chance to put it back on a whole page.
            // Leave in-progress resizes and gestures alone; their animation
            // owns the offset.
            if (resizePending.value ||
                resizeTransition.value != null ||
                swipeInProgress.value) {
              return;
            }
            target = dimension * firstPageInView.round();
          }
          target = clampDouble(
            target,
            pageController.position.minScrollExtent,
            pageController.position.maxScrollExtent,
          );
          reportFirstVisibleIndex((target / dimension).round());
          if ((target - pageController.offset).abs() < 0.5) {
            return;
          }
          var duration = const Duration(milliseconds: 200);
          var curve = Curves.easeInOut;
          if (pendingIndex == indexToScrollTo && pendingVelocity != null) {
            // A swipe navigation: carry the release speed into the landing so
            // a flick does not stop dead and then glide at a fixed pace.
            duration = _settleDuration(
              (target - pageController.offset).abs() / dimension,
              pendingVelocity,
            );
            curve = Curves.easeOutCubic;
          }
          pageController.animateTo(target, duration: duration, curve: curve);
        }

        /// Animates the row to the whole page closest to [offset].
        ///
        /// Used when a gesture is cancelled or does not reach the next page:
        /// the row returns to where the gesture started, not to the page
        /// nearest its displaced position.
        void settleTo(double offset) {
          final dimension = pageDimension();
          if (dimension == null) {
            return;
          }
          final target = clampDouble(
            (offset / dimension).round() * dimension,
            pageController.position.minScrollExtent,
            pageController.position.maxScrollExtent,
          );
          reportFirstVisibleIndex((target / dimension).round());
          if ((target - pageController.offset).abs() < 0.5) {
            return;
          }
          pageController.animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
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
          onSwipeBegin: (event) {
            // Reset anything the previous gesture left behind. Containers keep
            // their state across gestures, and a gesture that ended while this
            // one was disabled never reached it.
            swipeInProgress.value = false;
            swipePending.value = true;
            swipeStartOffset.value = pageController.hasClients
                ? pageController.offset
                : null;
            swipeSettleVelocity.value = null;
            swipeSettleIndex.value = null;
            swipeHistory.value
              ..reset()
              ..append(event.message.time, 0);
          },
          onSwipeUpdate: (event) {
            if (event.message.fingers != 3) {
              return;
            }
            if (!pageController.hasClients) {
              return;
            }
            // One physical swipe moves one container: the first axis the
            // arbiter sees owns the whole gesture, so a diagonal or noisy
            // swipe cannot scroll the workspace row and the tile row at once.
            if (!swipeArbiter.claim(swipeToken, direction)) {
              return;
            }
            final delta = direction == Axis.horizontal
                ? event.message.deltaX
                : event.message.deltaY;
            // The gesture can move on the other axis only; `pointerScroll`
            // rejects a zero delta.
            if (delta == 0) {
              return;
            }
            if (!swipeInProgress.value) {
              swipeInProgress.value = true;
              swipeStartOffset.value ??= pageController.offset;
            }

            final dimension = pageDimension();
            if (dimension == null) {
              return;
            }
            // The gesture is normalized to a fixed finger travel per page, not
            // to the page size: a full-width tile used to need a hand movement
            // as wide as the screen. The row follows the normalized progress.
            final progressDelta = delta / pageSwipe;
            swipeHistory.value.append(event.message.time, progressDelta);

            final position =
                pageController.position as ScrollPositionWithSingleContext;
            position.pointerScroll(progressDelta * dimension);
          },
          onSwipeEnd: (event) {
            swipePending.value = false;
            if (!swipeInProgress.value) {
              return;
            }
            swipeInProgress.value = false;
            // Niri pushes a zero delta at release: a pause before lifting the
            // fingers decays the fling instead of carrying an old speed.
            final velocity = swipeHistory.value.finish(event.message.time);
            final start = swipeStartOffset.value;
            swipeStartOffset.value = null;

            if (!pageController.hasClients) {
              return;
            }

            // libinput cancels a swipe when the finger count changes (say, a
            // fourth finger lands) or the touches turn out to be a palm. The
            // user committed to nothing, so put the row back where it started
            // instead of navigating. Snapping to the nearest page is not
            // enough: a cancelled drag may have passed the half-page mark.
            if (event.message.cancelled) {
              gestureLog.info('3-finger ${direction.name} swipe cancelled');
              if (start != null) {
                settleTo(start);
              } else {
                scrollToIndex(index);
              }
              return;
            }

            final dimension = pageDimension();
            if (dimension == null) {
              return;
            }
            // Page fractions from the start of the gesture. Under the fling
            // threshold the release snaps to the nearest page; above it, the
            // deceleration is projected and the row lands where it would have
            // stopped. This is GNOME Shell's and Niri's end-of-swipe model.
            final progress = start == null
                ? 0.0
                : (pageController.offset - start) / dimension;
            final flingSpeed = _flingThreshold / pageSwipe;
            final projected = velocity.abs() < flingSpeed
                ? progress
                : progress + velocity * _decelerationTime;
            final steps = math.min(1, math.max(-1, projected.round()));
            gestureLog.info(
              '3-finger ${direction.name} swipe: '
              'progress=${progress.toStringAsFixed(2)} '
              'velocity=${velocity.toStringAsFixed(2)} pages/s '
              'projected=${projected.toStringAsFixed(2)} steps=$steps',
            );

            final int? nextIndex;
            if (steps > 0) {
              nextIndex = index < children.length - 1 ? index + 1 : null;
            } else if (steps < 0) {
              nextIndex = index > 0 ? index - 1 : null;
            } else {
              nextIndex = null;
            }

            if (nextIndex != null && onIndexChanged != null) {
              // The rebuilt container runs `scrollToIndex` for the new index,
              // which either scrolls it into view or settles the row on whole
              // pages with the release velocity.
              swipeSettleVelocity.value = velocity.abs();
              swipeSettleIndex.value = nextIndex;
              onIndexChanged!(nextIndex);
            } else if (start != null) {
              // The gesture did not change the tile (or the selection is
              // already at the end): return to where it started rather than
              // to whatever page happens to be nearest the displaced offset.
              settleTo(start);
            } else {
              scrollToIndex(index);
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
              final pageExtent = pageViewport / visible;
              final targetOffset = _resolveInitialPage() * pageExtent;

              if (shownVisible.value != visible) {
                // Capture the layout currently shown so the animation starts
                // from it instead of jumping. A transition already running is
                // evaluated at its current instant, so changing the count
                // again mid-flight continues from there.
                final transition = resizeTransition.value;
                final fromExtent = transition == null
                    ? shownExtent.value ?? pageExtent
                    : transition.at(resizeProgress()).$1;
                final fromOffset = pageController.hasClients
                    ? pageController.offset
                    : fromExtent * initialPage;
                resizeTransition.value = _TileResize(
                  fromExtent: fromExtent,
                  fromLeading: fromExtent > 0 ? fromOffset / fromExtent : 0,
                  toExtent: pageExtent,
                  toLeading: pageExtent > 0 ? targetOffset / pageExtent : 0,
                );
                resizePending.value = true;
                shownVisible.value = visible;
                // The start of the transition is laid out by this frame;
                // begin ticking once it is on screen.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted || !resizePending.value) {
                    return;
                  }
                  resizePending.value = false;
                  resizeController.forward(from: 0);
                });
              }

              (double, double) visualLayout() {
                final transition = resizeTransition.value;
                final layout = transition == null
                    ? (pageExtent, targetOffset)
                    : transition.at(resizeProgress());
                shownExtent.value = layout.$1;
                return layout;
              }

              final resizing =
                  resizeTransition.value != null &&
                  (resizePending.value || resizeController.value < 1);

              return Align(
                alignment: isHorizontal
                    ? Alignment.centerLeft
                    : Alignment.topCenter,
                child: AnimatedBuilder(
                  // Rebuild when a swipe starts or ends too, so the pages
                  // about to slide in are built before the animation reaches
                  // them instead of during it.
                  animation: Listenable.merge([
                    resizeController,
                    swipeInProgress,
                    swipePending,
                  ]),
                  builder: (context, _) {
                    final (extent, offset) = visualLayout();
                    if (resizing && pageController.hasClients) {
                      // Set the offset without notifying scrollers: it is
                      // part of the same frame's layout as the page fraction
                      // below.
                      pageController.position.correctPixels(offset);
                    }
                    return CustomPaint(
                      foregroundPainter: _SelectionIndicatorPainter(
                        indicator: selectionIndicator,
                        position: selectionPosition,
                        pageController: pageController,
                        pageExtent: extent,
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
                            width: isHorizontal
                                ? pageViewport
                                : crossAxisExtent,
                            height: isHorizontal
                                ? crossAxisExtent
                                : pageViewport,
                            child: _PageRow(
                              controller: pageController,
                              viewportFraction: extent <= 0
                                  ? 1.0
                                  : extent / pageViewport,
                              direction: direction,
                              // One viewport of cache is enough for the tile
                              // just off either edge, which is already built
                              // when a resize starts moving it in or out. A
                              // swipe builds its destination page up front for
                              // the same reason.
                              cacheViewports:
                                  resizing ||
                                      buildsNeighbors ||
                                      swipeInProgress.value
                                  ? 1.0
                                  : 0.0,
                              allowImplicitScrolling:
                                  buildsNeighbors ||
                                  resizing ||
                                  swipeInProgress.value,
                              onScrollStart: () =>
                                  cursorTransition.begin(transitionToken),
                              onScrollEnd: () {
                                cursorTransition.end(transitionToken);
                                // The leading tile moved while the row was
                                // animating: report where the row landed.
                                final dimension = pageDimension();
                                if (reportedFirstVisibleIndex.value == null &&
                                    dimension != null) {
                                  reportFirstVisibleIndex(
                                    (pageController.offset / dimension).round(),
                                  );
                                }
                              },
                              delegate: SliverChildBuilderDelegate(
                                // A page is its own repaint boundary, so
                                // sliding the row translates a cached layer
                                // instead of re-rasterising every page on
                                // each frame of the swipe.
                                (context, index) => RepaintBoundary(
                                  key: children[index].key,
                                  child: children[index],
                                ),
                                childCount: children.length,
                                // A keyed page keeps its state when it moves
                                // to another index, instead of the page now at
                                // its old index taking that state over.
                                findChildIndexCallback: (key) {
                                  final index = children.indexWhere(
                                    (child) => child.key == key,
                                  );
                                  return index < 0 ? null : index;
                                },
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

/// The row geometry a page count change animates between.
///
/// A layout is a page size and a leading tile (in pages, fractional while the
/// leading tile changes to keep the selected tile in view). The scroll offset
/// follows from both, so the row never scrolls past the tile it wants to show.
class _TileResize {
  const _TileResize({
    required this.fromExtent,
    required this.fromLeading,
    required this.toExtent,
    required this.toLeading,
  });

  final double fromExtent;
  final double fromLeading;
  final double toExtent;
  final double toLeading;

  /// The page size and leading tile position at [progress].
  (double, double) at(double progress) {
    final extent = lerpDouble(fromExtent, toExtent, progress)!;
    final leading = lerpDouble(fromLeading, toLeading, progress)!;
    return (extent, leading * extent);
  }

  double get toOffset => toLeading * toExtent;
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

/// What a `PageView` builds for [SlidingContainer] (the same scrollable,
/// viewport and pages, never scrolled by the user), but its pages paint
/// whenever they are built.
///
/// A page slides to a new slot by translating it from the old one (see
/// `TileDropSlot`): a page whose slot is out of view, but which is shown
/// sliding over a visible one, must still paint. A `PageView` only paints
/// the pages whose slot is in view, so a tile sliding off screen vanished at
/// once instead. The viewport still clips whatever is outside it.
class _PageRow extends StatelessWidget {
  const _PageRow({
    required this.controller,
    required this.viewportFraction,
    required this.direction,
    required this.cacheViewports,
    required this.allowImplicitScrolling,
    required this.delegate,
    required this.onScrollStart,
    required this.onScrollEnd,
  });

  final PageController controller;

  /// The fraction of the viewport one page takes. Animated while the page
  /// count changes; the controller's own fraction stays at the mount value.
  final double viewportFraction;
  final Axis direction;

  /// How many viewports of pages to keep built on each side of the visible
  /// ones. A resize keeps the tiles just off either edge built.
  final double cacheViewports;

  /// Whether the pages off screen are part of the semantics tree
  /// (`PageView.allowImplicitScrolling`).
  final bool allowImplicitScrolling;
  final SliverChildDelegate delegate;
  final VoidCallback onScrollStart;
  final VoidCallback onScrollEnd;

  @override
  Widget build(BuildContext context) {
    final axisDirection = getAxisDirectionFromAxisReverseAndDirectionality(
      context,
      direction,
      false,
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Only this page row's own scroll: depth counts the viewports a
        // notification bubbled through, so a list inside a page arrives with a
        // deeper notification and must not hold the cursor.
        if (notification.depth == 0) {
          if (notification is ScrollStartNotification) {
            onScrollStart();
          } else if (notification is ScrollEndNotification) {
            onScrollEnd();
          }
        }
        return false;
      },
      child: Scrollable(
        axisDirection: axisDirection,
        controller: controller,
        physics: const NeverScrollableScrollPhysics(),
        scrollBehavior: ScrollConfiguration.of(
          context,
        ).copyWith(scrollbars: false),
        viewportBuilder: (context, position) => Viewport(
          scrollCacheExtent: ScrollCacheExtent.viewport(cacheViewports),
          axisDirection: axisDirection,
          offset: position,
          slivers: [
            _SliverPages(
              viewportFraction: viewportFraction,
              allowImplicitScrolling: allowImplicitScrolling,
              delegate: delegate,
            ),
          ],
        ),
      ),
    );
  }
}

/// `SliverFillViewport`'s pages, painting every built page.
class _SliverPages extends SliverMultiBoxAdaptorWidget {
  const _SliverPages({
    required super.delegate,
    required this.viewportFraction,
    required this.allowImplicitScrolling,
  });

  final double viewportFraction;
  final bool allowImplicitScrolling;

  @override
  RenderSliverFillViewport createRenderObject(BuildContext context) =>
      _RenderSliverPages(
        childManager: context as SliverMultiBoxAdaptorElement,
        viewportFraction: viewportFraction,
        allowImplicitScrolling: allowImplicitScrolling,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverFillViewport renderObject,
  ) {
    renderObject
      ..viewportFraction = viewportFraction
      ..allowImplicitScrolling = allowImplicitScrolling;
  }
}

class _RenderSliverPages extends RenderSliverFillViewport {
  _RenderSliverPages({
    required super.childManager,
    required super.viewportFraction,
    required super.allowImplicitScrolling,
  });

  /// `RenderSliverMultiBoxAdaptor.paint`, without skipping the pages whose
  /// slot is out of view: one may be shown sliding over a visible slot.
  @override
  void paint(PaintingContext context, Offset offset) {
    if (firstChild == null) {
      return;
    }
    final Offset mainAxisUnit;
    final Offset crossAxisUnit;
    final Offset originOffset;
    final bool addExtent;
    switch (applyGrowthDirectionToAxisDirection(
      constraints.axisDirection,
      constraints.growthDirection,
    )) {
      case AxisDirection.up:
        mainAxisUnit = const Offset(0, -1);
        crossAxisUnit = const Offset(1, 0);
        originOffset = offset + Offset(0, geometry!.paintExtent);
        addExtent = true;
      case AxisDirection.right:
        mainAxisUnit = const Offset(1, 0);
        crossAxisUnit = const Offset(0, 1);
        originOffset = offset;
        addExtent = false;
      case AxisDirection.down:
        mainAxisUnit = const Offset(0, 1);
        crossAxisUnit = const Offset(1, 0);
        originOffset = offset;
        addExtent = false;
      case AxisDirection.left:
        mainAxisUnit = const Offset(-1, 0);
        crossAxisUnit = const Offset(0, 1);
        originOffset = offset + Offset(geometry!.paintExtent, 0);
        addExtent = true;
    }
    var child = firstChild;
    while (child != null) {
      final mainAxisDelta = childMainAxisPosition(child);
      final crossAxisDelta = childCrossAxisPosition(child);
      var childOffset =
          originOffset +
          mainAxisUnit * mainAxisDelta +
          crossAxisUnit * crossAxisDelta;
      if (addExtent) {
        childOffset += mainAxisUnit * paintExtentOf(child);
      }
      context.paintChild(child, childOffset);
      child = childAfter(child);
    }
  }
}
