import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/pointer/model/pointer_focus.serializable.dart';
import 'package:shell/pointer/provider/pointer_focus.manager.dart';

/// While a pointer button is held, Flutter keeps dispatching moves to the
/// surface that received the press, even when the pointer is over another
/// surface. The mouse tracker reports the surface actually under the cursor
/// through [PointerFocusManager.enterSurface]; those reports must win, or a
/// native drag-and-drop never reaches the drop target.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PointerFocus _focus(int surfaceId) =>
      PointerFocus(surfaceId: surfaceId, globalOffset: Offset.zero);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('platform', JSONMethodCodec()),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('platform', JSONMethodCodec()),
      null,
    );
  });

  test('a held button keeps the surface under the cursor focused', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final manager = container.read(pointerFocusManagerProvider.notifier);

    // Press on surface 1, then move over surface 2: the mouse tracker enters
    // surface 2 and the pressed surface keeps reporting the stale hover.
    manager.startPotentialDrag();
    manager.enterSurface(_focus(1));
    manager.enterSurface(_focus(2));
    manager.hoverSurface(_focus(1));
    expect(container.read(pointerFocusManagerProvider)?.surfaceId, 2);

    // Moving back over the pressed surface is an enter event, which still wins.
    manager.enterSurface(_focus(1));
    expect(container.read(pointerFocusManagerProvider)?.surfaceId, 1);

    // Once the button is released, plain hovers drive the focus again.
    manager.stopPotentialDrag();
    manager.hoverSurface(_focus(2));
    expect(container.read(pointerFocusManagerProvider)?.surfaceId, 2);
  });
}
