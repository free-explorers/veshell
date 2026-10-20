import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/platform/model/request/activate_window/activate_window.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

/// A request can reach the compositor after the window it names has been torn
/// down (a client crash, or a focus change racing the teardown). Those stale
/// requests must not escape as unhandled `surface_doesnt_exist` exceptions:
/// they are a no-op, and the shell's own removal event clears the tile.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('platform', JSONMethodCodec());

  final request = ActivateWindowRequest(
    message: ActivateWindowMessage(surfaceId: 394, activate: true),
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'surface_doesnt_exist',
            message: "Surface 394 doesn't exist",
          );
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a request for a surface destroyed under it is dropped', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(platformManagerProvider.notifier).request(request),
      completes,
    );
  });

  test('an unexpected compositor error is still reported', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'invalid_arguments'),
        );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(platformManagerProvider.notifier).request(request),
      throwsA(isA<PlatformException>()),
    );
  });
}
