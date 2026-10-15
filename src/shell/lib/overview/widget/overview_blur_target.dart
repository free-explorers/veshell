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

    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 200),
    );

    useEffect(() {
      if (isDisplayed) {
        animationController.forward();
      } else {
        animationController.reverse();
      }
      return null;
    }, [isDisplayed]);

    final progressAnimation = useMemoized(
      () => CurvedAnimation(
        parent: animationController,
        curve: const Interval(0, 0.6, curve: Curves.easeInOut),
      ),
      [animationController],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Sigma grows with the screen so the frost is consistent across output
        // sizes.
        final maxSigma = frostSigmaFor(constraints.biggest);
        return AnimatedBuilder(
          animation: animationController,
          builder: (context, child) {
            final progress = progressAnimation.value;
            // Cache the frosted screen: while the overview is interacted with,
            // the blur is reused instead of recomputed, as long as the desktop
            // behind it is not itself repainting.
            return RepaintBoundary(
              child: FrostedSurface(
                blurSigma: maxSigma * progress,
                // A blurred background should read as glass, not merely out of
                // focus: lift its vibrancy a touch while the overview opens.
                saturation: 1 + 0.2 * progress,
                // Grain rides the blur (it only paints once blurred), so it
                // lives here rather than on the scrim, which does not blur.
                noise: true,
                tintOverContent: true,
                frame: false,
                highlight: false,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}
