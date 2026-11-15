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
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/widget/window.dart';

const _windowId = 'window-1';
const _surfaceId = 0;
const _tileSize = Size(1000, 800);
const _dialogSlotSize = Size(600, 500);

final _patches = <MetaWindowPatchMessage>[];

_FakeSurfaceState? _surfaceState;

class _FakeMetaWindowState extends MetaWindowState {
  @override
  MetaWindow build(String id) => const MetaWindow(
    id: _windowId,
    pid: 1,
    mapped: true,
    surfaceId: _surfaceId,
    needDecoration: false,
    gameModeActivated: false,
    scaleRatio: 1,
    geometry: Rect.fromLTWH(0, 0, 600, 500),
  );

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
}

class _FakeSurfaceState extends WlSurfaceState {
  @override
  WlSurface build(int surfaceId) {
    _surfaceState = this;
    return _surface(_dialogSlotSize);
  }

  /// The client commits a buffer of [size].
  void commitBuffer(Size size) {
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

Iterable<Size?> _requestedSizes() =>
    _patches.whereType<UpdateGeometry>().map((patch) => patch.value?.size);

Future<void> _pumpWindow(
  WidgetTester tester, {
  required bool sizesSurface,
}) async {
  final events = StreamController<PlatformEvent>.broadcast();
  addTearDown(events.close);
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = _tileSize;
  addTearDown(tester.view.reset);
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformManagerProvider.overrideWithValue(events.stream),
        // The surface's key routing reads the hotkey settings; no hotkey is
        // involved here.
        hotkeysActivatorProvider.overrideWithValue(const {}),
        metaWindowStateProvider(
          _windowId,
        ).overrideWith(_FakeMetaWindowState.new),
        wlSurfaceStateProvider(_surfaceId).overrideWith(_FakeSurfaceState.new),
      ],
      child: MaterialApp(
        home: CurrentMonitorName(
          name: 'M1',
          child: Center(
            child: SizedBox.fromSize(
              size: _tileSize,
              child: WindowWidget(
                metaWindowId: _windowId,
                focusNode: focusNode,
                sizesSurface: sizesSurface,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    _patches.clear();
    _surfaceState = null;
  });

  // A dialog panel fading out keeps painting a dialog that was just extracted
  // to a tile. It must not resize the window to its own slot: the new tile
  // owns the window, and the two configures would alternate.
  testWidgets('a host that does not own the window never resizes it', (
    tester,
  ) async {
    await _pumpWindow(tester, sizesSurface: false);
    _surfaceState!.commitBuffer(const Size(300, 200));
    await tester.pump();
    await tester.pump();

    expect(_requestedSizes(), isEmpty);
  });

  // Regression: an extracted dialog was resized back to its old slot by the
  // fading panel after the tile had corrected it once. The tile saw the same
  // (target, actual) mismatch again and skipped it as an already-sent
  // correction, so the window kept the dialog size inside the tile.
  testWidgets('a mismatch that comes back after being resolved is corrected', (
    tester,
  ) async {
    await _pumpWindow(tester, sizesSurface: true);
    await tester.pump();
    expect(_requestedSizes(), contains(_tileSize));

    // The client follows the configure: the mismatch is resolved.
    _surfaceState!.commitBuffer(_tileSize);
    await tester.pump();
    await tester.pump();

    // Something else resizes the window back to the dialog slot.
    _patches.clear();
    _surfaceState!.commitBuffer(_dialogSlotSize);
    await tester.pump();
    await tester.pump();

    expect(
      _requestedSizes(),
      contains(_tileSize),
      reason: 'the tile re-asserts its bounds for a new mismatch',
    );
  });
}
