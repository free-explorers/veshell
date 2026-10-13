import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/sliding_container.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/widget/window.dart';

const _windowId = 'window-1';
const _surfaceId = 0;
const _fullSize = Size(1000, 800);
const _halfSize = Size(500, 800);

final _patches = <MetaWindowPatchMessage>[];

_FakeMetaWindowState? _windowState;
_FakeSurfaceState? _surfaceState;

class _FakeMetaWindowState extends MetaWindowState {
  @override
  MetaWindow build(String id) {
    _windowState = this;
    return const MetaWindow(
      id: _windowId,
      pid: 1,
      mapped: true,
      surfaceId: _surfaceId,
      needDecoration: false,
      gameModeActivated: false,
      scaleRatio: 1,
      geometry: Rect.fromLTWH(0, 0, 1000, 800),
    );
  }

  @override
  Future<void> patch(
    MetaWindowPatchMessage patch, {
    bool propagate = true,
  }) async {
    _patches.add(patch);
    if (patch is UpdateGeometry && patch.value != null) {
      state = state.copyWith(geometry: patch.value);
    }
  }

  /// Simulates a client committing a resized buffer without re-setting its xdg
  /// window geometry, which a client is not required to do. The geometry then
  /// no longer reflects the size the surface actually renders at.
  void keepStaleGeometry() {
    state = state.copyWith(geometry: const Rect.fromLTWH(0, 0, 1000, 800));
  }
}

class _FakeSurfaceState extends WlSurfaceState {
  @override
  WlSurface build(int surfaceId) {
    _surfaceState = this;
    return _surface(_fullSize);
  }

  void setBuffer(Size size) {
    state = _surface(size);
  }

  WlSurface _surface(Size size) => WlSurface(
    surfaceId: _surfaceId,
    role: SurfaceRole.xdgToplevel,
    texture: SurfaceTexture(id: 1, size: size),
    scale: 1,
    subsurfacesBelow: IList(),
    subsurfacesAbove: IList(),
    inputRegion: Rect.zero,
  );
}

void main() {
  setUp(() {
    _patches.clear();
    _windowState = null;
    _surfaceState = null;
  });

  testWidgets(
    'restoring the displayed tile count resizes the window back to full',
    (tester) async {
      final events = StreamController<PlatformEvent>.broadcast();
      addTearDown(events.close);
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1000, 800);
      addTearDown(tester.view.reset);

      final visible = ValueNotifier<int>(2);
      addTearDown(visible.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            platformManagerProvider.overrideWithValue(events.stream),
            metaWindowStateProvider(
              _windowId,
            ).overrideWith(_FakeMetaWindowState.new),
            wlSurfaceStateProvider(
              _surfaceId,
            ).overrideWith(_FakeSurfaceState.new),
          ],
          child: MaterialApp(
            home: CurrentMonitorName(
              name: 'M1',
              child: ValueListenableBuilder<int>(
                valueListenable: visible,
                builder: (context, visibleCount, _) => Center(
                  child: SizedBox(
                    width: 1000,
                    height: 800,
                    child: SlidingContainer(
                      index: 0,
                      visible: visibleCount,
                      children: [
                        WindowWidget(
                          metaWindowId: _windowId,
                          focusNode: focusNode,
                        ),
                        const SizedBox(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Two tiles are visible: the shell patched the window to half a screen.
      expect(
        _patches.whereType<UpdateGeometry>().map((patch) => patch.value?.width),
        contains(_halfSize.width),
      );

      // The client resized its buffer to the half tile but left its xdg window
      // geometry at full.
      _surfaceState!.setBuffer(_halfSize);
      _windowState!.keepStaleGeometry();
      await tester.pump();

      // Back to a single tile: the surface must be pulled back to full even
      // though its stale geometry already reads as full.
      _patches.clear();
      visible.value = 1;
      await tester.pump();
      await tester.pump();

      expect(
        _patches.whereType<UpdateGeometry>().map((patch) => patch.value?.width),
        contains(_fullSize.width),
        reason: 'the committed buffer, not the stale geometry, drives the size',
      );
    },
  );

  testWidgets(
    'every tile-count change re-asserts the size, not just the first one',
    (tester) async {
      final events = StreamController<PlatformEvent>.broadcast();
      addTearDown(events.close);
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(1000, 800);
      addTearDown(tester.view.reset);

      final visible = ValueNotifier<int>(1);
      addTearDown(visible.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            platformManagerProvider.overrideWithValue(events.stream),
            metaWindowStateProvider(
              _windowId,
            ).overrideWith(_FakeMetaWindowState.new),
            wlSurfaceStateProvider(
              _surfaceId,
            ).overrideWith(_FakeSurfaceState.new),
          ],
          child: MaterialApp(
            home: CurrentMonitorName(
              name: 'M1',
              child: ValueListenableBuilder<int>(
                valueListenable: visible,
                builder: (context, visibleCount, _) => Center(
                  child: SizedBox(
                    width: 1000,
                    height: 800,
                    child: SlidingContainer(
                      index: 0,
                      visible: visibleCount,
                      children: [
                        WindowWidget(
                          metaWindowId: _windowId,
                          focusNode: focusNode,
                        ),
                        const SizedBox(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // A guard that locks after the first correction (for instance one keyed
      // on a stringified `Size`, which is not reliable in release builds) would
      // let later cycles leave the window at the previous tile's size.
      for (var cycle = 0; cycle < 2; cycle++) {
        _patches.clear();
        _surfaceState!.setBuffer(_fullSize);
        visible.value = 2;
        await tester.pump();
        await tester.pump();
        expect(
          _patches.whereType<UpdateGeometry>().map(
            (patch) => patch.value?.width,
          ),
          contains(_halfSize.width),
          reason: 'cycle $cycle must shrink to the half tile',
        );

        _patches.clear();
        _surfaceState!.setBuffer(_halfSize);
        visible.value = 1;
        await tester.pump();
        await tester.pump();
        expect(
          _patches.whereType<UpdateGeometry>().map(
            (patch) => patch.value?.width,
          ),
          contains(_fullSize.width),
          reason: 'cycle $cycle must grow back to the full tile',
        );
      }
    },
  );
}
