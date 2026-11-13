import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/surface_visibility.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/widget/window_placeholder.dart';

/// The content of a [PersistentWindow] tile as it is shown in its slot: the
/// placeholder, or the window's live buffer.
///
/// A copy for display only: the placeholder must neither take focus nor
/// launch, and a live window is drawn from its texture so a second
/// `MetaSurfaceWidget` does not report input and render origins for the same
/// surface.
class TileFace extends ConsumerWidget {
  const TileFace({
    required this.window,
    required this.layoutSize,
    required this.windowSize,
    this.focused = false,
    this.elevation = 0,
    this.radius = 0,
    super.key,
  });

  final PersistentWindow window;

  /// The size the content is laid out at, before it is fitted to the slot.
  final Size layoutSize;

  /// The size a displayed window is laid out at, anchored top-left, like a
  /// tile shows it until the client resizes to its new slot.
  final Size windowSize;

  /// Draws the focused placeholder look regardless of the real focus.
  final bool focused;

  final double elevation;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = ExcludeFocus(
      child: WindowPlaceholder(
        isSelected: true,
        window: window,
        displayFocused: focused,
      ),
    );
    final metaWindowId = window.metaWindowId;
    return Material(
      elevation: elevation,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      // The rect and the layout size reshape together, so filling distorts
      // by a fraction of a pixel at most.
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox.fromSize(
          size: layoutSize,
          child: metaWindowId == null
              ? placeholder
              : OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: windowSize.width,
                  maxWidth: windowSize.width,
                  minHeight: windowSize.height,
                  maxHeight: windowSize.height,
                  child: _LiveWindow(
                    metaWindowId: metaWindowId,
                    fallback: placeholder,
                  ),
                ),
        ),
      ),
    );
  }
}

/// The window's current buffer, fitted into the tile. Only the texture is
/// drawn: a second `SurfaceWidget` would also report input and render origins
/// for the surface and confuse the compositor.
class _LiveWindow extends ConsumerWidget {
  const _LiveWindow({required this.metaWindowId, required this.fallback});

  final MetaWindowId metaWindowId;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A tile can briefly outlive its window; see `WindowWidget`.
    int? surfaceId;
    try {
      surfaceId = ref.watch(
        metaWindowStateProvider(metaWindowId).select((w) => w.surfaceId),
      );
    } on Object {
      surfaceId = null;
    }
    final texture = surfaceId == null
        ? null
        : ref.watch(wlSurfaceStateProvider(surfaceId).select((s) => s.texture));
    if (texture == null || texture.size.isEmpty) return fallback;
    return FittedBox(
      child: SizedBox.fromSize(
        size: texture.size,
        child: SurfaceVisibilityProbe(
          surfaceId: surfaceId!,
          child: Texture(textureId: texture.id),
        ),
      ),
    );
  }
}
