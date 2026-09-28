import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

/// Half-circle status indicator attached to the right-center edge of its
/// host button.
///
/// The flat edge faces the button and the round side points outward. It is
/// shared by the workspace unread indicator (primary, steady) and the screen
/// recording indicator (red, blinking).
class NotificationDot extends HookWidget {
  /// Const constructor.
  const NotificationDot({
    this.color,
    this.size = 10,
    this.blinking = false,
    super.key,
  });

  /// Indicator color. Defaults to the theme primary color, used for unread
  /// notifications.
  final Color? color;

  /// Indicator diameter: the height of the half circle. Its width is half of
  /// this.
  final double size;

  /// Whether the indicator hard-blinks between fully visible and hidden. Used
  /// for the red screen-recording warning.
  final bool blinking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 500),
    );
    useEffect(() {
      if (blinking) {
        controller.repeat();
      } else {
        controller
          ..stop()
          ..value = 1;
      }
      return null;
    }, [blinking, controller]);

    final dot = Container(
      width: size / 2,
      height: size,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.primary,
        borderRadius: BorderRadius.horizontal(right: Radius.circular(size / 2)),
      ),
    );

    if (!blinking) {
      return dot;
    }
    return FadeTransition(
      opacity: controller.drive(
        TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween<double>(1), weight: 1),
          TweenSequenceItem(tween: ConstantTween<double>(1), weight: 1),
          TweenSequenceItem(tween: ConstantTween<double>(0), weight: 1),
        ]),
      ),
      child: dot,
    );
  }
}
