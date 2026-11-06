import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/tile_grab/provider/tile_grab_controller.dart';

/// Shows the grabbing cursor over a whole monitor while a tile is held.
///
/// The held pointer travels over other tiles, client surfaces and monitors, so
/// the cursor is claimed per monitor view rather than by the grabbed tile.
/// Place it above everything else in the monitor's stack; it is translucent,
/// so drop targets beneath still receive the pointer.
class TileGrabCursor extends ConsumerWidget {
  const TileGrabCursor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHeld = ref.watch(
      tileGrabControllerProvider.select((grab) => grab != null),
    );
    return Positioned.fill(
      child: MouseRegion(
        // The default (opaque) would end the hit test here and starve the
        // whole monitor of pointer events.
        opaque: false,
        cursor: isHeld ? SystemMouseCursors.grabbing : MouseCursor.defer,
      ),
    );
  }
}
