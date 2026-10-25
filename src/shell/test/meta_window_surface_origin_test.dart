import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';

MetaWindow _window({
  required MetaWindowDisplayMode? displayMode,
  required Offset? position,
  required Rect? geometry,
}) => MetaWindow(
  id: 'window',
  pid: 1,
  mapped: true,
  surfaceId: 1,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  displayMode: displayMode,
  position: position,
  geometry: geometry,
);

void main() {
  test('window placement exposes origin, client size and surface offset', () {
    final window = _window(
      displayMode: MetaWindowDisplayMode.floating,
      position: const Offset(48, 48),
      geometry: const Rect.fromLTWH(24, 21, 2512, 1356),
    );

    final placement = window.windowPlacement!;
    expect(placement.origin, const Offset(48, 48));
    expect(placement.clientSize, const Size(2512, 1356));
    expect(placement.geometryOffset, const Offset(24, 21));
    expect(placement.surfaceOrigin, const Offset(24, 27));
    expect(placement.clientRect, const Rect.fromLTWH(48, 48, 2512, 1356));
  });

  test('floating surface origin excludes a Wayland CSD geometry offset', () {
    final window = _window(
      displayMode: MetaWindowDisplayMode.floating,
      position: const Offset(48, 48),
      geometry: const Rect.fromLTWH(24, 21, 2512, 1356),
    );

    expect(window.floatingSurfaceOrigin, const Offset(24, 27));
  });

  test('floating X11 surface origin is its root position', () {
    final window = _window(
      displayMode: MetaWindowDisplayMode.floating,
      position: const Offset(710, 326),
      geometry: const Rect.fromLTWH(0, 0, 1188, 800),
    );

    expect(window.floatingSurfaceOrigin, const Offset(710, 326));
  });

  test('non-floating windows keep the render-box basis', () {
    final window = _window(
      displayMode: MetaWindowDisplayMode.maximized,
      position: const Offset(48, 48),
      geometry: const Rect.fromLTWH(24, 21, 2512, 1356),
    );

    expect(window.floatingSurfaceOrigin, isNull);
  });

  test('a floating window without a position has no native basis', () {
    final window = _window(
      displayMode: MetaWindowDisplayMode.floating,
      position: null,
      geometry: const Rect.fromLTWH(24, 21, 2512, 1356),
    );

    expect(window.floatingSurfaceOrigin, isNull);
  });
}
