import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary, TextureBox;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
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

/// How long a frame captured for a close is kept while the window stays: a
/// client may ask first (unsaved changes) and close much later, or not at all.
const _closeFrameLifetime = Duration(seconds: 5);

/// The window's own texture, kept by the compositor past its close (see
/// `State::release_surface_textures`), and where it was painted in the tile.
typedef WindowCloseTexture = ({int id, Rect rect});

/// A tile's last frame, as the shell asked its window to close.
class _CloseFrame {
  _CloseFrame(this.metaWindowId, this.image, this.texture);

  final MetaWindowId metaWindowId;

  /// What the shell painted of the tile, with a hole where the window's
  /// texture is: `toImageSync` does not draw external textures.
  final ui.Image? image;

  final WindowCloseTexture? texture;
}

/// A tile's window wrapping back into its placeholder (see
/// [WindowCloseTransition]); [done] ends it.
class WindowClosing {
  WindowClosing._(this.image, this.texture, this.done);

  /// What the shell painted of the tile, or `null` when the window closed on
  /// its own.
  final ui.Image? image;

  /// The window's own last frame, painted over [image].
  final WindowCloseTexture? texture;

  final VoidCallback done;
}

/// The closing of the window a tile shows, while it plays.
///
/// Each new [closeRequests] (the shell asked [metaWindowId] to close) captures
/// the tile's frame from the [RenderRepaintBoundary] at [frameKey], while the
/// window still paints: what the shell drew, and where the window's texture
/// ([windowTextureId]) sits, which the compositor keeps past the close. Once
/// the window is gone ([metaWindowId] turns `null`), the closing starts, with
/// that frame when it is the window's, or without one when the window closed
/// on its own. A window shown again (a splash handing over, a surface
/// recreated) cancels it. The kept texture is handed to [releaseTexture] once
/// the closing is over. Nothing is captured or played unless [enabled].
WindowClosing? useWindowClosing({
  required MetaWindowId? metaWindowId,
  required int closeRequests,
  required GlobalKey frameKey,
  required bool enabled,
  int? Function()? windowTextureId,
  void Function(int textureId)? releaseTexture,
}) {
  final context = useContext();
  final pending = useRef<_CloseFrame?>(null);
  final expiry = useRef<Timer?>(null);
  final closing = useRef<WindowClosing?>(null);
  final shown = useRef(metaWindowId);
  final rebuild = useState(0);
  // Read when the closing ends, which can be after this build's callbacks.
  final release = useRef(releaseTexture)..value = releaseTexture;

  void dropPending() {
    expiry.value?.cancel();
    expiry.value = null;
    pending.value?.image?.dispose();
    pending.value = null;
  }

  // Its transition may still be painting it this frame.
  void finish(WindowClosing? ended) {
    if (ended == null) {
      return;
    }
    if (ended.texture case final texture?) {
      release.value?.call(texture.id);
    }
    if (ended.image case final image?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    }
  }

  void end(WindowClosing ended) {
    if (!identical(closing.value, ended)) {
      return;
    }
    closing.value = null;
    finish(ended);
    if (context.mounted) {
      rebuild.value++;
    }
  }

  if (shown.value != metaWindowId) {
    final gone = shown.value;
    shown.value = metaWindowId;
    final frame = pending.value;
    expiry.value?.cancel();
    expiry.value = null;
    pending.value = null;
    finish(closing.value);
    closing.value = null;
    if (enabled && gone != null && metaWindowId == null) {
      final own = frame != null && frame.metaWindowId == gone ? frame : null;
      if (own == null) {
        frame?.image?.dispose();
      }
      late final WindowClosing started;
      started = WindowClosing._(own?.image, own?.texture, () => end(started));
      closing.value = started;
    } else {
      frame?.image?.dispose();
    }
  }

  useEffect(() {
    final id = metaWindowId;
    if (closeRequests == 0 || !enabled || id == null) {
      return null;
    }
    _CloseFrame? take() {
      final boundary = frameKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.attached) {
        return null;
      }
      ui.Image image;
      try {
        image = boundary.toImageSync(
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
      } on Object {
        // Not painted yet, or being repainted: the frame after has it.
        return null;
      }
      final textureId = windowTextureId?.call();
      return _CloseFrame(
        id,
        image,
        textureId == null ? null : _findTexture(boundary, textureId),
      );
    }

    void keep(_CloseFrame frame) {
      dropPending();
      pending.value = frame;
      expiry.value = Timer(_closeFrameLifetime, () {
        if (identical(pending.value, frame)) {
          dropPending();
        }
      });
    }

    if (take() case final frame?) {
      keep(frame);
    } else {
      WidgetsBinding.instance
        ..addPostFrameCallback((_) {
          if (context.mounted && shown.value == id) {
            if (take() case final frame?) {
              keep(frame);
            }
          }
        })
        ..ensureVisualUpdate();
    }
    return null;
  }, [closeRequests]);

  useEffect(
    () => () {
      dropPending();
      finish(closing.value);
      closing.value = null;
    },
    const [],
  );

  return closing.value;
}

/// Where the texture [textureId] is painted under [boundary], in its
/// coordinates; `null` when it is not painted there.
WindowCloseTexture? _findTexture(RenderObject boundary, int textureId) {
  TextureBox? found;
  void visit(RenderObject child) {
    if (found != null) {
      return;
    }
    if (child is TextureBox && child.textureId == textureId && child.hasSize) {
      found = child;
      return;
    }
    child.visitChildren(visit);
  }

  boundary.visitChildren(visit);
  final box = found;
  if (box == null) {
    return null;
  }
  return (
    id: textureId,
    rect: MatrixUtils.transformRect(
      box.getTransformTo(boundary),
      Offset.zero & box.size,
    ),
  );
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
        // The outgoing window of a close is not shrunk here: it is gone, and
        // [WindowCloseTransition] plays the closing over the tile instead.
        final closing = animation.status == AnimationStatus.reverse;
        return _cardOpening(closing ? 1.0 : animation.value, child!);
      },
    );
  }
}

/// The window shows through the card before the opening starts to grow.
const Curve _fadeCurve = Interval(0, 0.3, curve: Curves.easeOut);
const Curve _revealCurve = Interval(0.2, 1, curve: Curves.easeInOutCubic);

/// [child] seen through the opening at [t] of [WindowOpenTransition]: through
/// the card at 0, the whole tile at 1.
Widget _cardOpening(double t, Widget child) => Opacity(
  opacity: _fadeCurve.transform(t),
  child: ClipRRect(
    clipper: _CardOpeningClipper(_revealCurve.transform(t)),
    clipBehavior: t >= 1 ? Clip.none : Clip.antiAlias,
    child: child,
  ),
);

/// Wraps a closed window back into its placeholder's centered card: the
/// opening of [WindowOpenTransition] played backwards, over the placeholder
/// that is already shown whole behind it.
///
/// The window has no surface left by then. Closed by the shell, it shows the
/// tile's last frame: [image], what the shell painted, under [texture], the
/// window's last frame which the compositor kept. Closed on its own, it shows
/// a plain surface in its place. The opening narrows
/// from the tile's edges to the card while its corners round, then the frame
/// fades out into the card's content. [onDone] is called once it has.
class WindowCloseTransition extends HookWidget {
  const WindowCloseTransition({
    required this.image,
    required this.onDone,
    this.texture,
    super.key,
  });

  /// What the shell painted of the tile, over the whole tile; `null` paints a
  /// plain surface instead.
  final ui.Image? image;

  /// The window's own last frame, kept by the compositor, painted where it
  /// was over [image].
  final WindowCloseTexture? texture;

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: windowOpenTransitionDuration,
    );
    useEffect(() {
      unawaited(
        controller.forward().whenComplete(() {
          if (context.mounted) {
            onDone();
          }
        }),
      );
      return null;
    }, [controller]);
    final progress = useAnimation(controller);
    final frame = image;
    return IgnorePointer(
      child: _cardOpening(
        1 - progress,
        frame == null
            ? ColoredBox(color: Theme.of(context).colorScheme.surface)
            : RawImage(image: frame, fit: BoxFit.fill),
      ),
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
/// window, and shows an incoming one under the closing window.
///
/// Fading the outgoing placeholder out would show the workspace behind the
/// tile around the opening while it is still smaller than the tile. An
/// incoming placeholder is shown whole at once while [WindowCloseTransition]
/// wraps the window back into its card over it ([underClosing]); otherwise
/// (animations off, a floating tile) it fades in, over the start of the shared
/// duration: that duration is sized for the opening, which is slower than a
/// plain fade needs to be.
class PlaceholderSwapTransition extends StatelessWidget {
  const PlaceholderSwapTransition({
    required this.animation,
    required this.child,
    this.underClosing = false,
    super.key,
  });

  final Animation<double> animation;
  final Widget child;

  /// A closing window is wrapping back into this placeholder's card.
  final bool underClosing;

  static const Curve _fadeInCurve = Interval(0, 0.4, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final outgoing = animation.status == AnimationStatus.reverse;
        return Opacity(
          opacity: outgoing || underClosing
              ? 1
              : _fadeInCurve.transform(animation.value),
          child: child,
        );
      },
    );
  }
}
