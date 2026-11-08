import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary, TextureBox;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/frozen_close_textures.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/shared/widget/frosted_surface.dart';
import 'package:shell/theme/provider/theme.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/window_close_requests.dart';
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
  WindowClosing._(this.image, this.texture, this.done, [this._liveTextureId]);

  /// What the shell painted of the tile, or `null` when the window closed on
  /// its own.
  final ui.Image? image;

  /// The window's own last frame, painted over [image].
  final WindowCloseTexture? texture;

  /// The live texture [texture] stands in for, when the compositor froze a
  /// copy for the close: kept too, and released with it.
  final int? _liveTextureId;

  final VoidCallback done;
}

/// The closing of the window a tile shows, while it plays.
///
/// Each new [closeRequests] (the shell asked [metaWindowId] to close) captures
/// the tile's frame from the [RenderRepaintBoundary] at [frameKey], while the
/// window still paints: what the shell drew, and where the window's texture
/// ([windowTextureId]) sits. The compositor answers the request with a copy
/// of that texture ([FrozenCloseTextures]), which the client can no longer
/// paint over, and keeps the live one past the close as a fallback. The
/// capture runs in the request's own notification, before the request reaches
/// the client, so a fast client cannot destroy the surface first. Once
/// the window is gone ([metaWindowId] turns `null`), the closing starts, with
/// that frame when it is the window's, or with the last texture remembered
/// from the live window when the application closed it itself (the shell's
/// frame is only captured for a close it requested). A window shown again (a
/// splash handing over, a surface recreated) cancels it. The kept texture is
/// handed to [releaseTexture] once
/// the closing is over. Nothing is captured or played unless [enabled].
WindowClosing? useWindowClosing({
  required WidgetRef ref,
  required PersistentWindowId windowId,
  required MetaWindowId? metaWindowId,
  required int closeRequests,
  required GlobalKey frameKey,
  required bool enabled,
  int? Function()? windowTextureId,
  void Function(int textureId)? releaseTexture,

  /// Called once the displayed window is gone (however it closed) with its
  /// content size and whether it covered its tile, so the preview the
  /// compositor persisted can be drawn at the same place.
  void Function(Size size, bool fullBleed)? onWindowClosed,
}) {
  final context = useContext();
  final pending = useRef<_CloseFrame?>(null);
  final expiry = useRef<Timer?>(null);
  final closing = useRef<WindowClosing?>(null);
  final shown = useRef(metaWindowId);
  // Where the displayed window's texture was painted, remembered while it is
  // still live: an application that closes its own window leaves no request
  // to capture it, and its surface can be gone by the time the next frame
  // builds.
  final lastTexture =
      useRef<({MetaWindowId windowId, WindowCloseTexture texture})?>(null);
  final lastWindowFrame =
      useRef<({MetaWindowId windowId, Size size, bool fullBleed})?>(null);
  final captured = useRef(0);
  final retryScheduled = useRef(0);
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
    if (ended._liveTextureId case final live?) {
      release.value?.call(live);
    }
    if (ended.texture case final texture?) {
      release.value?.call(texture.id);
      if (lastTexture.value?.texture.id == texture.id) {
        lastTexture.value = null;
      }
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

  _CloseFrame? take(MetaWindowId id) {
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

  void capture(int generation, MetaWindowId id) {
    if (captured.value >= generation) {
      return;
    }
    if (take(id) case final frame?) {
      keep(frame);
      captured.value = generation;
      return;
    }
    // Not painted yet, or being repainted: the frame after has it.
    if (retryScheduled.value >= generation) {
      return;
    }
    retryScheduled.value = generation;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (context.mounted &&
            captured.value < generation &&
            shown.value == id) {
          capture(generation, id);
        }
      })
      ..ensureVisualUpdate();
  }

  // Capture synchronously when the shell asks the window to close: the close
  // request reaches the client immediately afterwards, and its surface (with
  // the texture id and its place in the tile) can be gone by the time the next
  // frame builds. Waiting for the rebuild is what made the last frame show up
  // only sometimes.
  ref.listen(windowCloseRequestsProvider(windowId), (previous, next) {
    if (!enabled || next <= (previous ?? 0)) {
      return;
    }
    if (metaWindowId case final id?) {
      capture(next, id);
    }
  });

  // Remember where the displayed window's texture is painted while it is
  // still alive: an application closing its own window leaves no request to
  // capture it, and the surface (with the texture id) can be gone by the time
  // the next frame builds.
  useEffect(() {
    final id = metaWindowId;
    if (id == null) {
      return null;
    }
    final textureId = windowTextureId?.call();
    if (textureId == null) {
      return null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        return;
      }
      final boundary = frameKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.attached) {
        return;
      }
      if (_findTexture(boundary, textureId) case final texture?) {
        lastTexture.value = (windowId: id, texture: texture);
        // The window's content geometry, not the surface buffer: client-side
        // decorations and shadow margins sit outside the window.
        Rect? geometry;
        try {
          geometry = ref.read(metaWindowStateProvider(id)).geometry;
        } on Object {
          // The window went away between the frame and this callback.
        }
        final size = geometry?.size ?? texture.rect.size;
        final tile = boundary.size;
        final fullBleed =
            size.width >= tile.width - 1 && size.height >= tile.height - 1;
        lastWindowFrame.value = (
          windowId: id,
          size: size,
          fullBleed: fullBleed,
        );
      }
    });
    return null;
  });

  if (shown.value != metaWindowId) {
    final gone = shown.value;
    shown.value = metaWindowId;
    final frame = pending.value;
    expiry.value?.cancel();
    expiry.value = null;
    pending.value = null;
    finish(closing.value);
    closing.value = null;
    final frozen = gone == null
        ? null
        : ref.read(frozenCloseTexturesProvider.notifier).take(gone);
    if (gone != null && metaWindowId == null) {
      if (lastWindowFrame.value case final last? when last.windowId == gone) {
        onWindowClosed?.call(last.size, last.fullBleed);
      }
    }
    if (enabled && gone != null && metaWindowId == null) {
      final own = frame != null && frame.metaWindowId == gone ? frame : null;
      if (own == null) {
        frame?.image?.dispose();
      }
      final remembered = lastTexture.value;
      final live =
          own?.texture ??
          (remembered != null && remembered.windowId == gone
              ? remembered.texture
              : null);
      // The frozen copy covers the same surface as the live texture, at the
      // same place.
      final texture = frozen != null && live != null
          ? (id: frozen, rect: live.rect)
          : live;
      late final WindowClosing started;
      started = WindowClosing._(
        own?.image,
        texture,
        () => end(started),
        identical(texture, live) ? null : live?.id,
      );
      closing.value = started;
    } else {
      frame?.image?.dispose();
    }
  }

  // Fallback for a request that happened before this tile was built (or
  // before the listener existed): capture as soon as it can.
  useEffect(() {
    final id = metaWindowId;
    if (closeRequests == 0 || !enabled || id == null) {
      return null;
    }
    capture(closeRequests, id);
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
/// window's last frame which the compositor kept. Closed by the application
/// itself, it shows that kept texture over a plain surface in its place. The
/// opening narrows from the tile's edges to the card while its corners round
/// and its content blurs towards the stored preview's look, then the frame
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
    Widget content = frame == null
        ? ColoredBox(color: Theme.of(context).colorScheme.surface)
        : RawImage(image: frame, fit: BoxFit.fill);
    // `toImageSync` leaves a hole where the window's external texture is: the
    // compositor's retained last frame is painted over it, where it was.
    if (texture case final kept?) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          content,
          Positioned.fromRect(
            rect: kept.rect,
            child: Texture(textureId: kept.id, freeze: true),
          ),
        ],
      );
    }
    // The closing window frosts into its placeholder's look: the same glass
    // the dialog backdrop and the placeholder use, ramped by the animation,
    // so the frame lands on the stored preview instead of cutting to it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scheme = Theme.of(context).colorScheme;
        final region = texture?.rect.size ?? constraints.biggest;
        return IgnorePointer(
          child: _cardOpening(
            1 - progress,
            FrostedSurface(
              blurSigma: frostSigmaFor(region) * progress,
              saturation: 1 + 0.20 * progress,
              tint: progress > 0
                  ? frostedGlassTint(
                      scheme,
                    ).withAlpha((frostedWashAlpha * progress).round())
                  : null,
              tintOverContent: true,
              frame: false,
              highlight: false,
              noise: true,
              noiseOpacity: progress,
              child: content,
            ),
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
