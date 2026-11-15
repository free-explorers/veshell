import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/widget/immersive_fullscreen.dart';
import 'package:shell/window/widget/window.dart';

const _windowId = 'window-1';
const _surfaceId = 0;
const _monitorSize = Size(1600, 1000);
const _tileSize = Size(1000, 800);

final _patches = <MetaWindowPatchMessage>[];
var _isFullscreen = true;

/// Whether the fake client commits a buffer at each size the shell requests.
var _clientFollows = true;
_FakeSurfaceState? _surfaceState;

class _FakeMetaWindowState extends MetaWindowState {
  @override
  MetaWindow build(String id) => MetaWindow(
    id: _windowId,
    pid: 1,
    mapped: true,
    surfaceId: _surfaceId,
    needDecoration: false,
    gameModeActivated: false,
    scaleRatio: 1,
    isFullscreen: _isFullscreen,
    geometry: Offset.zero & _tileSize,
  );

  @override
  Future<void> patch(
    MetaWindowPatchMessage patch, {
    bool propagate = true,
  }) async {
    _patches.add(patch);
    if (patch is UpdateGeometry && patch.value != null) {
      state = state.copyWith(geometry: patch.value);
      if (_clientFollows) {
        _surfaceState?.commitBuffer(patch.value!.size);
      }
    }
  }
}

class _FakePlatformManager extends PlatformManager {
  @override
  Stream<PlatformEvent> build() => const Stream.empty();

  @override
  Future<void> request(PlatformRequest request) async {}
}

class _FakeSurfaceState extends WlSurfaceState {
  @override
  WlSurface build(int surfaceId) {
    _surfaceState = this;
    return _surface(_tileSize);
  }

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

Size? _lastRequestedSize() =>
    _patches.whereType<UpdateGeometry>().lastOrNull?.value?.size;

/// Pumps a maximized tile whose window [_isFullscreen], and focuses it unless
/// [focused] is false.
Future<FocusNode> _pumpTile(WidgetTester tester, {bool focused = true}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = _monitorSize;
  addTearDown(tester.view.reset);
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformManagerProvider.overrideWith(_FakePlatformManager.new),
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
                immersiveFullscreen: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (focused) {
    focusNode.requestFocus();
  }
  await tester.pumpAndSettle();
  return focusNode;
}

/// Lets the input idle long enough to zoom, then lets the zoom settle.
Future<void> _idle(WidgetTester tester) async {
  await tester.pump(immersiveFullscreenIdleDelay);
  await tester.pumpAndSettle();
}

/// The views of the window: its tile, plus the route while it is out of it.
int _surfaceCount() => find.byType(MetaSurfaceWidget).evaluate().length;

void main() {
  setUp(() {
    _patches.clear();
    _isFullscreen = true;
    _clientFollows = true;
    _surfaceState = null;
  });

  testWidgets('an idle fullscreen client covers its whole monitor', (
    tester,
  ) async {
    await _pumpTile(tester);
    expect(_surfaceCount(), 1);

    await tester.pump(immersiveFullscreenIdleDelay ~/ 2);
    expect(_surfaceCount(), 1, reason: 'not idle long enough yet');

    await _idle(tester);
    expect(_surfaceCount(), 2, reason: 'the route shows the surface');
    expect(_lastRequestedSize(), _monitorSize);
    expect(tester.getSize(find.byType(MetaSurfaceWidget).last), _monitorSize);
  });

  testWidgets('the zoom grows from the tile and shrinks back into it', (
    tester,
  ) async {
    await _pumpTile(tester);
    final tileRect = tester.getRect(find.byType(MetaSurfaceWidget));
    // A real client takes a few frames to follow the monitor-sized configure.
    _clientFollows = false;

    await tester.pump(immersiveFullscreenIdleDelay);
    await tester.pump();
    expect(_surfaceCount(), 2);
    expect(
      tester.getRect(find.byType(MetaSurfaceWidget).last),
      tileRect,
      reason: 'the zoom starts over the tile',
    );
    await tester.pump(immersiveFullscreenTransitionDuration ~/ 2);
    final midway = tester.getRect(find.byType(MetaSurfaceWidget).last);
    _surfaceState!.commitBuffer(_monitorSize);
    _clientFollows = true;
    expect(midway.width, greaterThan(tileRect.width));
    expect(midway.width, lessThan(_monitorSize.width));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(MetaSurfaceWidget).last),
      Offset.zero & _monitorSize,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    await tester.pump(
      immersiveFullscreenTransitionDuration - const Duration(milliseconds: 1),
    );
    final landing = tester.getRect(find.byType(MetaSurfaceWidget).last);
    expect(landing.center.dx, closeTo(tileRect.center.dx, 2));
    expect(landing.width, closeTo(tileRect.width, 10));
    await tester.pumpAndSettle();
    expect(_surfaceCount(), 1);
  });

  // Regression: the route kept sizing the window to the monitor during the
  // return zoom, so the tile and the route bounced the client between both
  // sizes for the whole transition.
  testWidgets('the return zoom resizes the window to the tile only once', (
    tester,
  ) async {
    await _pumpTile(tester);
    await _idle(tester);
    expect(_lastRequestedSize(), _monitorSize);

    _patches.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    final requested = _patches
        .whereType<UpdateGeometry>()
        .map((patch) => patch.value?.size)
        .toList();
    expect(requested, isNotEmpty);
    expect(requested, everyElement(_tileSize));
  });

  testWidgets('pointer motion brings it back into the tile', (tester) async {
    await _pumpTile(tester);
    await _idle(tester);
    expect(_lastRequestedSize(), _monitorSize);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(_surfaceCount(), 1);
    expect(_lastRequestedSize(), _tileSize);

    // Idling again zooms out again.
    await _idle(tester);
    expect(_surfaceCount(), 2);
  });

  testWidgets('a key brings it back without taking the keyboard', (
    tester,
  ) async {
    final focusNode = await _pumpTile(tester);
    await _idle(tester);
    expect(focusNode.hasFocus, isTrue, reason: 'the route never takes focus');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();

    expect(_surfaceCount(), 1);
    expect(_lastRequestedSize(), _tileSize);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('a window that is not fullscreen stays in its tile', (
    tester,
  ) async {
    _isFullscreen = false;
    await _pumpTile(tester);
    await _idle(tester);

    expect(_surfaceCount(), 1);
    expect(_lastRequestedSize(), isNot(_monitorSize));
  });

  testWidgets('an unfocused tile stays in its tile', (tester) async {
    await _pumpTile(tester, focused: false);
    await _idle(tester);

    expect(_surfaceCount(), 1);
  });

  testWidgets('losing focus brings it back into the tile', (tester) async {
    final focusNode = await _pumpTile(tester);
    await _idle(tester);
    expect(_surfaceCount(), 2);

    focusNode.unfocus();
    await tester.pumpAndSettle();

    expect(_surfaceCount(), 1);
    expect(_lastRequestedSize(), _tileSize);
  });

  testWidgets('another display mode never leaves its tile', (tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = _monitorSize;
    addTearDown(tester.view.reset);
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformManagerProvider.overrideWith(_FakePlatformManager.new),
          hotkeysActivatorProvider.overrideWithValue(const {}),
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
            child: Center(
              child: SizedBox.fromSize(
                size: _tileSize,
                child: WindowWidget(
                  metaWindowId: _windowId,
                  focusNode: focusNode,
                  displayMode: DisplayMode.fullscreen,
                  immersiveFullscreen: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    await _idle(tester);

    expect(_surfaceCount(), 1);
  });
}
