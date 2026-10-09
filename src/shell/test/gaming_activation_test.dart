import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/widget/meta_surface_gaming_overlay.dart';
import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';

const _windowId = 'window-1';

MetaWindow _window() => const MetaWindow(
  id: _windowId,
  pid: 1,
  mapped: true,
  surfaceId: 0,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
);

/// Collector shared by the throwaway notifier instances: a
/// [MetaWindowState] is auto-disposed and remounted, so the override must be
/// able to mint a fresh instance each time.
final _patches = <MetaWindowPatchMessage>[];

class _RecordingMetaWindowState extends MetaWindowState {
  @override
  MetaWindow build(String id) => _window();

  @override
  Future<void> patch(
    MetaWindowPatchMessage patch, {
    bool propagate = true,
  }) async {
    _patches.add(patch);
  }
}

void main() {
  setUp(_patches.clear);

  testWidgets(
    'activation fires on route completion even without a Hero flight',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            metaWindowStateProvider(
              _windowId,
            ).overrideWith(_RecordingMetaWindowState.new),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (context, _, __) =>
                          const GamingActivationTrigger(
                            metaWindowId: _windowId,
                            child: ColoredBox(color: Colors.red),
                          ),
                    ),
                  ),
                  child: const Text('zoom'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('zoom'));
      await tester.pumpAndSettle();

      final activations = _patches.whereType<UpdateGameModeActivated>();
      expect(activations, isNotEmpty);
      expect(activations.every((patch) => patch.id == _windowId), isTrue);
      expect(activations.every((patch) => patch.value), isTrue);
    },
  );

  testWidgets('the trigger is inert outside a route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          metaWindowStateProvider(
            _windowId,
          ).overrideWith(_RecordingMetaWindowState.new),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: GamingActivationTrigger(
            metaWindowId: _windowId,
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_patches, isEmpty);
  });
}
