import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/subsurface_state.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';

void main() {
  test('a re-bound subsurface remaps even when its texture is unchanged', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const surfaceId = 9;
    // Keep both auto-dispose providers alive for the whole test.
    container
      ..listen(subsurfaceStateProvider(surfaceId), (_, _) {})
      ..listen(wlSurfaceStateProvider(surfaceId), (_, _) {});

    final subsurface = container.read(
      subsurfaceStateProvider(surfaceId).notifier,
    );
    final wlSurface = container.read(
      wlSurfaceStateProvider(surfaceId).notifier,
    );

    // Mirrors one compositor `commit_surface`: the surface state is committed
    // first, then the subsurface records the commit.
    void bind(int parent) => subsurface.initialize(parent: parent);
    void commitTexture(int textureId) => wlSurface.commit(
      role: SurfaceRole.subsurface,
      textureId: textureId,
      surfaceSize: const Size(341, 808),
      scale: 1,
      subsurfacesBelow: IList<int>(),
      subsurfacesAbove: IList<int>(),
      inputRegion: Rect.zero,
    );
    void commitSubsurface() => subsurface.commit(position: Offset.zero);

    // First binding: the texture goes from null to id 9, then the subsurface
    // commits, so the texture-change listener maps it.
    bind(8);
    commitTexture(9);
    commitSubsurface();
    expect(container.read(subsurfaceStateProvider(surfaceId)).mapped, isTrue);

    // Firefox re-binds the same surface under the next xdg_popup. The texture
    // id is identical, so no texture-change notification reaches the
    // subsurface. The commit must still be able to flip `mapped` back on.
    bind(13);
    expect(container.read(subsurfaceStateProvider(surfaceId)).mapped, isFalse);
    commitTexture(9);
    commitSubsurface();
    expect(
      container.read(subsurfaceStateProvider(surfaceId)).mapped,
      isTrue,
      reason: 'a re-bound subsurface must remap on commit',
    );
  });
}
