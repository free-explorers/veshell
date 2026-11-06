import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/theme/provider/theme.dart';
import 'package:shell/window/widget/window_placeholder.dart';

/// How long a persistent tile takes to swap its placeholder for its window.
const windowOpenTransitionDuration = Duration(milliseconds: 550);

/// Key for a tile's placeholder/window switcher that keeps the opening
/// animation for the tile's own launches.
///
/// The tile's displayed window can change without any launch: a splash hands
/// over to the real window, an application recreates its surface, a dialog is
/// promoted. Each of these goes through a moment with no window, so the
/// switcher would replay the opening as if the tile had just been launched.
///
/// [launching] tells whether the placeholder is showing a launch that has not
/// produced its window yet. When a window appears without one, the key
/// changes: the switcher is remounted and shows the window at once, dropping
/// any placeholder that had started to fade in over the previous window.
Key useWindowSwitcherKey({required bool hasWindow, required bool launching}) {
  final generation = useRef(0);
  final hadWindow = useRef(hasWindow);
  final launchPending = useRef(false);

  if (hasWindow && !hadWindow.value && !launchPending.value) {
    generation.value++;
  }
  hadWindow.value = hasWindow;
  launchPending.value = !hasWindow && launching;

  return ValueKey(generation.value);
}

/// Uncovers a tile's first window through its placeholder's centered card.
///
/// The window is never moved or scaled: it sits at its final place and size,
/// as if it had always been there behind the placeholder. The card acts as an
/// opening onto it. The window first shows through the card's rect and
/// rounded corners, replacing the card's content, then the opening expands
/// to the tile's edges and its corners straighten, uncovering the rest.
///
/// The window is laid out at the full tile size for the whole animation, so
/// the client is configured once at its final size.
class WindowOpenTransition extends StatelessWidget {
  const WindowOpenTransition({
    required this.animation,
    required this.child,
    super.key,
  });

  /// Runs from 0 (the opening is the card) to 1 (the opening is the tile).
  final Animation<double> animation;
  final Widget child;

  /// The window shows through the card before the opening starts to grow.
  static const Curve _fadeCurve = Interval(0, 0.3, curve: Curves.easeOut);
  static const Curve _revealCurve = Interval(
    0.2,
    1,
    curve: Curves.easeInOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // The tree keeps the same shape at rest: dropping the wrappers once
        // the animation ends would remount the window widget and lose its
        // state. At t = 1 each wrapper is a no-op instead.
        //
        // Closing does not replay the opening backwards: the outgoing window
        // stays whole while the placeholder fades in over it.
        final closing = animation.status == AnimationStatus.reverse;
        final t = closing ? 1.0 : animation.value;
        return Opacity(
          opacity: _fadeCurve.transform(t),
          child: ClipRRect(
            clipper: _CardOpeningClipper(_revealCurve.transform(t)),
            clipBehavior: t >= 1 ? Clip.none : Clip.antiAlias,
            child: child,
          ),
        );
      },
    );
  }
}

/// The opening onto the window: the placeholder's card at 0, the whole tile
/// at 1.
class _CardOpeningClipper extends CustomClipper<RRect> {
  const _CardOpeningClipper(this.progress);

  final double progress;

  @override
  RRect getClip(Size size) {
    final inset = placeholderCardInset * (1 - progress);
    return RRect.fromLTRBR(
      size.width * inset,
      size.height * inset,
      size.width * (1 - inset),
      size.height * (1 - inset),
      Radius.circular(surfaceRadius * (1 - progress)),
    );
  }

  @override
  bool shouldReclip(_CardOpeningClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// Keeps an outgoing placeholder fully opaque around the opening onto the
/// window, and fades an incoming one in over the closing window.
///
/// Fading the outgoing placeholder out would show the workspace behind the
/// tile around the opening while it is still smaller than the tile. The
/// fade-in only takes the start of the shared duration: that duration is
/// sized for the opening, which is slower than a plain fade needs to be.
class PlaceholderSwapTransition extends StatelessWidget {
  const PlaceholderSwapTransition({
    required this.animation,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final Widget child;

  static const Curve _fadeInCurve = Interval(0, 0.4, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final outgoing = animation.status == AnimationStatus.reverse;
        return Opacity(
          opacity: outgoing ? 1 : _fadeInCurve.transform(animation.value),
          child: child,
        );
      },
    );
  }
}
