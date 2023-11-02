import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/common/state/xdg_surface_state.dart';
import 'package:zenith/ui/common/xdg_toplevel_surface.dart';

/// Scales down a window if it doesn't want to resize to the screen size. We don't want windows to be drawn on top of
/// others just because they don't want to resize.
class FittedWindow extends ConsumerWidget {
  final XdgToplevelSurface window;
  final Alignment alignment;

  const FittedWindow({
    Key? key,
    required this.window,
    required this.alignment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                Rect visibleBounds = ref.watch(
                    xdgSurfaceStatesProvider(window.viewId)
                        .select((v) => v.visibleBounds));

                Size biggest = constraints.biggest;
                Size size = visibleBounds.size;

                // Flutter likes to position things at subpixel coordinates and the view texture ends up
                // at non-integer coordinates, which means that the image will be a bit blurry.
                // If this is the case, just shift the view by half a pixel in the appropriate directions.
                // This is only a problem when the window fits in the available space. Otherwise, it's going
                // to be scaled down so it will be a bit blurry anyway.
                bool fits = size.width <= biggest.width &&
                    size.height <= biggest.height;

                bool shiftHorizontally = fits && (size.width % 2 != biggest.width % 2);

                return Transform.translate(
                  offset: Offset(
                    shiftHorizontally ? -0.5 : 0,
                    0,
                  ),
                  child: child!,
                );
              },
              child: window,
            ),
          ),
        );
      },
    );
  }
}
