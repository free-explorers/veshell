import 'dart:ui' show ImageFilter;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview.dart' show overviewBlurSigma;
import 'package:shell/screen/model/screen.serializable.dart';

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

    final blurAnimation = useMemoized(
      () => Tween<double>(begin: 0, end: overviewBlurSigma).animate(
        CurvedAnimation(
          parent: animationController,
          curve: const Interval(0, 0.6, curve: Curves.easeInOut),
        ),
      ),
      [animationController],
    );

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) => ImageFiltered(
        enabled: blurAnimation.value > 0.01,
        imageFilter: ImageFilter.blur(
          sigmaX: blurAnimation.value,
          sigmaY: blurAnimation.value,
        ),
        child: child,
      ),
      child: child,
    );
  }
}
