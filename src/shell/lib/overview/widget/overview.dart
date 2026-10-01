import 'dart:math';

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

/// Blur applied to the rest of the screen while the overview is open.
///
/// Applied to the rest of the screen by `OverviewBlurTarget`; the scrim below
/// reuses it so the white wash follows the same curve it always did.
const overviewBlurSigma = 16.0;

/// The overview overlay: search, clock and content panes.
///
/// The rest of the screen behind it is blurred by `OverviewBlurTarget`; this
/// widget only fades the overlay in and lays the translucent white wash over
/// the blurred layer.
class OverviewWidget extends HookConsumerWidget {
  const OverviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);

    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 200),
    );

    ref.listen(
      overviewStateProvider(screenId).select((state) => state.isDisplayed),
      (previous, next) {
        if (next) {
          animationController.forward();
        } else {
          animationController.reverse();
        }
      },
    );

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        if (animationController.value > 0.0) {
          return _OverviewScrim(
            animationController: animationController,
            child: child,
          );
        }
        return const SizedBox.shrink();
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
                      // Snap the split to whole logical pixels. The content
                      // pane hosts live Wayland surfaces, and a fractional
                      // origin makes Flutter sample their external textures
                      // bilinearly (an "always blurry" window), while the
                      // workspace tiles land on whole pixels.
                      final searchWidth = min(
                        max(
                          _minSearchEngineWidth,
                          availableWidth *
                              _searchEngineFlex /
                              (_searchEngineFlex + _overviewContentFlex),
                        ),
                        availableWidth,
                      ).roundToDouble();
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

/// The translucent wash drawn over the blurred layer while the overview is
/// open, plus the fade of the overview content itself.
///
/// This used to be an `AnimatedBlurBackground` wrapping the whole overview in a
/// `BackdropFilter`; the blur now lives on the rest of the screen
/// (`OverviewBlurTarget`), so this only tints and fades.
class _OverviewScrim extends HookWidget {
  const _OverviewScrim({
    required this.animationController,
    this.child,
    super.key,
  });

  final Widget? child;
  final AnimationController animationController;

  @override
  Widget build(BuildContext context) {
    // Mirror the old tint curve: it derived the white-wash alpha from the
    // animated blur sigma (0..16), so keep the same 0..16*255/100 ramp.
    final tintAnimation = useMemoized(
      () => Tween<double>(begin: 0, end: 1).animate(
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

    return ColoredBox(
      color: Colors.white.withAlpha(
        (255 * (overviewBlurSigma * tintAnimation.value) / 100).round(),
      ),
      child: Opacity(opacity: opacityAnimation.value, child: child),
    );
  }
}
