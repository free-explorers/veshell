import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/shared/widget/frosted_surface.dart';

/// The part of a screen that the overview blurs while it is open.
///
/// The overview used to blur its own backdrop with a `BackdropFilter`, which
/// the engine re-renders offscreen on every frame even when nothing behind it
/// changed (and, with Impeller, restores the whole screen); blurring the rest
/// of the screen itself is far cheaper.
///
/// An `ImageFiltered` has to wrap what it blurs, so a sibling overlay cannot
/// apply it. The recipe lives here, with the overview: `ScreenWidget` composes
/// the screen through this widget instead of owning the blur itself.
///
/// Once the frost has settled it is baked into an image and drawn as a plain
/// blit. A filtered layer is not cached across frames: while the overview was
/// open, any animation anywhere (a sparkline, a hover, the opening ramp) made
/// the engine re-apply the full-screen blur, saturation and grain on every
/// output, every frame. Freezing the settled result keeps the backdrop
/// identical (it is occluded and blurred anyway) and makes those frames cheap.
class OverviewBlurTarget extends HookConsumerWidget {
  /// Creates the blurred layer the overview sits over.
  const OverviewBlurTarget({
    required this.screenId,
    required this.child,
    super.key,
  });

  /// The screen whose overview state drives the blur.
  final ScreenId screenId;

  /// The layer the overview blurs.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDisplayed = ref.watch(
      overviewStateProvider(screenId).select((state) => state.isDisplayed),
    );

    final animationController = useAnimationController(duration: frostDuration);
    final boundaryKey = useMemoized(GlobalKey.new);
    final frozen = useState<ui.Image?>(null);
    final frozenSize = useRef<Size?>(null);

    // An unmount while frozen (a screen subtree rebuilt with the overview
    // open) would otherwise leak the full-screen capture.
    useEffect(
      () =>
          () => frozen.value?.dispose(),
      const [],
    );

    useEffect(() {
      if (!isDisplayed) {
        // Thaw before the closing ramp: it has to lift from the live frost, and
        // drawing a stale snapshot while the scan runs would show the old
        // backdrop sliding away from the real one.
        _thaw(frozen, frozenSize);
        animationController.reverse();
        return null;
      }

      var cancelled = false;

      Future<void> freeze() async {
        if (cancelled) return;
        // Read the ratio before the frame gap; the capture needs the settled
        // frame painted.
        final pixelRatio = View.of(context).devicePixelRatio;
        await SchedulerBinding.instance.endOfFrame;
        if (cancelled) return;
        final boundary = boundaryKey.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary || boundary.size.isEmpty) return;
        final ui.Image image;
        try {
          image = await boundary.toImage(pixelRatio: pixelRatio);
        } on Object {
          // A capture that fails leaves the live frost in place: slower, not
          // broken.
          return;
        }
        if (cancelled) {
          image.dispose();
          return;
        }
        _swap(frozen, frozenSize, boundary.size, image);
      }

      unawaited(animationController.forward().whenComplete(freeze));
      return () => cancelled = true;
    }, [isDisplayed]);

    // A screen subtree rebuilt while the overview is displayed (a monitor
    // reconnect across a suspend, say) must come back already frosted rather
    // than blurring in from nothing.
    final settled = useRef(false);
    if (!settled.value) {
      settled.value = true;
      animationController.value = isDisplayed ? 1 : 0;
    }

    final progressAnimation = useMemoized(
      () => CurvedAnimation(parent: animationController, curve: frostCurve),
      [animationController],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // Sigma grows with the screen so the frost is consistent across output
        // sizes.
        final maxSigma = frostSigmaFor(size);
        final image = frozen.value;
        // A resize invalidates the capture; the live frost takes over until
        // the next open bakes a matching one. The stale capture is released
        // rather than kept: a later return to its size would show it again.
        final frozenImage = image != null && frozenSize.value == size
            ? image
            : null;
        if (image != null && frozenImage == null) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && frozen.value == image) {
              _thaw(frozen, frozenSize);
            }
          });
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            // Kept mounted while frozen: the workspaces, tiles and live
            // surfaces behind the overview own state and focus hand-offs,
            // which re-inflating would lose (see the test).
            Offstage(
              offstage: frozenImage != null,
              child: AnimatedBuilder(
                animation: animationController,
                builder: (context, child) {
                  final progress = progressAnimation.value;
                  return RepaintBoundary(
                    key: boundaryKey,
                    child: FrostedSurface(
                      blurSigma: maxSigma * progress,
                      // A blurred background should read as glass, not merely
                      // out of focus: lift its vibrancy a touch while the
                      // overview opens.
                      saturation: 1 + 0.2 * progress,
                      // Grain rides the blur (it only paints once blurred) and
                      // fades with the ramp, so it lives here rather than on
                      // the scrim.
                      noise: true,
                      noiseOpacity: progress,
                      tintOverContent: true,
                      frame: false,
                      highlight: false,
                      child: child,
                    ),
                  );
                },
                child: child,
              ),
            ),
            if (frozenImage != null)
              RawImage(
                image: frozenImage,
                scale: View.of(context).devicePixelRatio,
                fit: BoxFit.fill,
              ),
          ],
        );
      },
    );
  }

  /// Replaces the frozen backdrop, releasing the old image once the frame that
  /// stopped painting it is done.
  void _swap(
    ValueNotifier<ui.Image?> frozen,
    ObjectRef<Size?> frozenSize,
    Size size,
    ui.Image image,
  ) {
    final previous = frozen.value;
    frozenSize.value = size;
    frozen.value = image;
    if (previous != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  /// Drops the frozen backdrop before the closing ramp.
  void _thaw(ValueNotifier<ui.Image?> frozen, ObjectRef<Size?> frozenSize) {
    final previous = frozen.value;
    frozenSize.value = null;
    frozen.value = null;
    if (previous != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }
}
