import 'dart:math';
import 'dart:ui';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview_content.dart';
import 'package:shell/overview/widget/search/search_engine.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/widget/clock.dart';
import 'package:shell/theme//provider/theme.dart';

/// Minimum width the search engine is allowed to shrink to.
const _minSearchEngineWidth = 548.0;

/// Gap between the search engine and the overview content.
const _overviewGap = 16.0;

/// Flex weights keeping the search engine / overview content split at 2:5.
const _searchEngineFlex = 2;
const _overviewContentFlex = 5;

class OverviewWidget extends HookConsumerWidget {
  const OverviewWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);

    final overviewAnimationController = useAnimationController(
      duration: const Duration(milliseconds: 200),
    );

    ref.listen(
      overviewStateProvider(screenId).select((state) => state.isDisplayed),
      (previous, next) {
        if (next) {
          overviewAnimationController.forward();
        } else {
          overviewAnimationController.reverse();
        }
      },
    );

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
          final focusScopeNode = useFocusScopeNode(
            debugLabel: 'OverviewFocusNode',
          );
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
                          .read(overviewStateProvider(screenId).notifier)
                          .toggle(),
                      icon: const Icon(MdiIcons.close),
                      style: IconButton.styleFrom(
                        shape: const RoundedRectangleBorder(),
                        minimumSize: const Size.square(panelSize),
                      ),
                    ),
                  ],
                ),
                const Positioned(top: 12, child: ClockWidget()),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 64,
                    right: 64,
                    bottom: 64,
                    top: 96,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = max<double>(
                        0,
                        constraints.maxWidth - _overviewGap,
                      );
                      final searchWidth = min(
                        max(
                          _minSearchEngineWidth,
                          availableWidth *
                              _searchEngineFlex /
                              (_searchEngineFlex + _overviewContentFlex),
                        ),
                        availableWidth,
                      );
                      return Row(
                        children: [
                          SizedBox(
                            width: searchWidth,
                            child: const SearchEngine(),
                          ),
                          const SizedBox(width: _overviewGap),
                          const Expanded(child: OverviewContentPane()),
                        ],
                      );
                    },
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
          color: Colors.white.withAlpha(
            (255 * blurAnimation.value / 100).round(),
          ),
          child: Opacity(opacity: opacityAnimation.value, child: child),
        ),
      ),
    );
  }
}
