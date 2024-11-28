import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/search/widget/search_engine.dart';
import 'package:shell/overview/widget/overview_content.dart';
import 'package:shell/screen/provider/current_screen_id.dart';
import 'package:shell/shared/widget/clock.dart';
import 'package:shell/theme/theme.dart';

class OverviewWidget extends HookConsumerWidget {
  const OverviewWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = ref.watch(currentScreenIdProvider);

    final overviewAnimationController = useAnimationController(
      duration: const Duration(milliseconds: 200),
    );

    ref.listen(
        overviewStateProvider(screenId).select((state) => state.isDisplayed),
        (previous, next) {
      print('overviewIsDisplayedProvider changed $previous $next');
      if (next) {
        overviewAnimationController.forward();
      } else {
        overviewAnimationController.reverse();
      }
    });

    return AnimatedBuilder(
      animation: overviewAnimationController,
      builder: (context, child) {
        if (overviewAnimationController.value > 0.0) {
          return AnimatedBlurBackground(
            animationController: overviewAnimationController,
            child: child,
          );
        } else {
          return Container();
        }
      },
      child: HookConsumer(
        builder: (context, ref, child) {
          final focusScopeNode =
              useFocusScopeNode(debugLabel: 'OverviewFocusNode');
          return FocusScope(
            node: focusScopeNode,
            autofocus: true,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => ref
                          .read(
                            overviewStateProvider(screenId).notifier,
                          )
                          .toggle(),
                      icon: const Icon(MdiIcons.close),
                      style: IconButton.styleFrom(
                        shape: const RoundedRectangleBorder(),
                        minimumSize: const Size.square(panelSize),
                      ),
                    ),
                  ],
                ),
                const Positioned(
                  top: 12,
                  child: ClockWidget(),
                ),
                const Padding(
                  padding: EdgeInsets.only(
                    left: 64,
                    right: 64,
                    bottom: 64,
                    top: 96,
                  ),
                  child: Row(
                    children: [
                      Flexible(flex: 2, child: SearchEngine()),
                      SizedBox(width: 16),
                      Flexible(flex: 5, child: OverviewContent()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AnimatedBlurBackground extends HookWidget {
  const AnimatedBlurBackground({
    required this.animationController,
    this.child,
    this.sigma = 16,
    super.key,
  });

  final Widget? child;
  final AnimationController animationController;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final blurAnimation = useMemoized(
      () => Tween<double>(begin: 0, end: sigma).animate(
        CurvedAnimation(
          parent: animationController,
          curve: const Interval(0, 0.6, curve: Curves.easeInOut),
        ),
      ),
      [animationController],
    );

    final opacityAnimation = useMemoized(
      () => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: animationController,
          curve: const Interval(0.4, 1, curve: Curves.easeInOut),
        ),
      ),
      [animationController],
    );

    return ClipRRect(
      // Clip it cleanly.
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurAnimation.value,
          sigmaY: blurAnimation.value,
        ),
        child: ColoredBox(
          color: Colors.white.withOpacity(blurAnimation.value / 100),
          child: Opacity(
            opacity: opacityAnimation.value,
            child: child,
          ),
        ),
      ),
    );
  }
}
