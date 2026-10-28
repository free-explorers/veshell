import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/mpris/model/mpris_manager_state.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';
import 'package:shell/shared/mpris/provider/mpris_manager.dart';
import 'package:shell/shortcut_manager/model/media_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/widget/shortcut_manager.dart';
import 'package:shell/tile_grab/model/tile_grab.dart';
import 'package:shell/tile_grab/provider/tile_grab_controller.dart';
import 'package:shell/window/model/window_id.serializable.dart';

/// An [MprisManager] whose control methods only record the call, so the media
/// hotkeys can be tested without a session bus.
class _FakeMprisManager extends MprisManager {
  final calls = <String>[];

  @override
  Future<MprisManagerState> build() async =>
      MprisManagerState(players: <String, MprisPlayer>{}.lock);

  @override
  void playPause() => calls.add('playPause');

  @override
  void next() => calls.add('next');

  @override
  void previous() => calls.add('previous');

  @override
  void stop() => calls.add('stop');
}

/// A tile grab that is started by hand and records the intents it consumes.
class _FakeTileGrab extends TileGrabController {
  final intents = <Intent>[];

  @override
  TileGrab? build() => null;

  void hold() => state = const TileGrab(
    pointer: 1,
    windowId: PersistentWindowId('w'),
    sourceWorkspaceId: 'ws',
    sourceScreenId: 'screen',
    originRect: Rect.fromLTWH(0, 0, 100, 100),
    grabAnchor: Offset.zero,
    pressPosition: Offset.zero,
    globalPosition: Offset.zero,
  );

  void release() => state = null;

  @override
  bool handleIntent(Intent intent) {
    if (state == null) return false;
    intents.add(intent);
    return true;
  }
}

void main() {
  group('getActionIntent', () {
    test('maps the media actions to their intents', () {
      expect(
        getActionIntent(HotkeysAction.mediaPlayPause),
        isA<MediaPlayPauseIntent>(),
      );
      expect(getActionIntent(HotkeysAction.mediaNext), isA<MediaNextIntent>());
      expect(
        getActionIntent(HotkeysAction.mediaPrevious),
        isA<MediaPreviousIntent>(),
      );
      expect(getActionIntent(HotkeysAction.mediaStop), isA<MediaStopIntent>());
    });

    test('maps every action to an intent', () {
      for (final action in HotkeysAction.values) {
        expect(getActionIntent(action), isA<Intent>());
      }
    });
  });

  testWidgets('focus-loss Super release does not open Overview', (
    tester,
  ) async {
    var overviewCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hotkeysActivatorProvider.overrideWithValue({})],
        child: VeshellShortcutManager(
          child: Actions(
            actions: {
              ToggleOverviewIntent: CallbackAction<ToggleOverviewIntent>(
                onInvoke: (_) {
                  overviewCount++;
                  return null;
                },
              ),
            },
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(primaryFocus, isNotNull);

    final keyboard = HardwareKeyboard.instance;
    void dispatch(KeyEvent event) {
      keyboard.handleKeyEvent(event);
      ServicesBinding.instance.keyEventManager.keyMessageHandler!(
        KeyMessage([event], null),
      );
    }

    const physical = PhysicalKeyboardKey.metaLeft;
    const logical = LogicalKeyboardKey.superKey;
    dispatch(
      KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
      ),
    );
    dispatch(
      KeyUpEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
        synthesized: true,
      ),
    );
    expect(overviewCount, 0);

    dispatch(
      KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
      ),
    );
    dispatch(
      KeyUpEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
      ),
    );
    expect(overviewCount, 1);
  });

  group('while a tile is held', () {
    late _FakeTileGrab grab;
    late int overviewCount;
    late List<Intent> navigated;

    Future<void> pumpManager(
      WidgetTester tester, {
      Map<ShortcutActivator, Intent> activators = const {},
    }) async {
      grab = _FakeTileGrab();
      overviewCount = 0;
      navigated = [];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hotkeysActivatorProvider.overrideWithValue(activators),
            tileGrabControllerProvider.overrideWith(() => grab),
          ],
          child: VeshellShortcutManager(
            child: Actions(
              actions: {
                ToggleOverviewIntent: CallbackAction<ToggleOverviewIntent>(
                  onInvoke: (_) {
                    overviewCount++;
                    return null;
                  },
                ),
                NavigateIntent: CallbackAction<NavigateIntent>(
                  onInvoke: (intent) {
                    navigated.add(intent);
                    return null;
                  },
                ),
              },
              child: const Focus(autofocus: true, child: SizedBox()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    bool dispatch(KeyEvent event) {
      final keyboard = HardwareKeyboard.instance;
      final handled = keyboard.handleKeyEvent(event);
      return ServicesBinding.instance.keyEventManager.keyMessageHandler!(
            KeyMessage([event], null),
          ) ||
          handled;
    }

    const superPhysical = PhysicalKeyboardKey.metaLeft;
    const superLogical = LogicalKeyboardKey.superKey;
    const superDown = KeyDownEvent(
      physicalKey: superPhysical,
      logicalKey: superLogical,
      timeStamp: Duration.zero,
    );
    const superUp = KeyUpEvent(
      physicalKey: superPhysical,
      logicalKey: superLogical,
      timeStamp: Duration.zero,
    );

    testWidgets('the grabbing Super release neither opens the overview nor '
        'reaches the client', (tester) async {
      await pumpManager(tester);
      dispatch(superDown);
      grab.hold();
      await tester.pump();
      grab.release();
      await tester.pump();
      expect(dispatch(superUp), isTrue);
      expect(overviewCount, 0);

      // The next lone Super tap is an ordinary one again.
      dispatch(superDown);
      dispatch(superUp);
      expect(overviewCount, 1);
    });

    testWidgets('navigation goes to the held tile, not the focused context', (
      tester,
    ) async {
      const right = NavigateIntent(NavigationDirection.right);
      await pumpManager(
        tester,
        activators: {LogicalKeySet(LogicalKeyboardKey.arrowRight): right},
      );
      grab.hold();
      await tester.pump();
      await simulateKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await simulateKeyUpEvent(LogicalKeyboardKey.arrowRight);
      expect(grab.intents, [right]);
      expect(navigated, isEmpty);

      grab.release();
      await tester.pump();
      await simulateKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await simulateKeyUpEvent(LogicalKeyboardKey.arrowRight);
      expect(navigated, [right]);
    });
  });

  testWidgets('media keys drive the active MPRIS player', (tester) async {
    final fake = _FakeMprisManager();
    final activators = <ShortcutActivator, Intent>{
      LogicalKeySet.fromSet({LogicalKeyboardKey.mediaPlayPause}):
          getActionIntent(HotkeysAction.mediaPlayPause),
      LogicalKeySet.fromSet({LogicalKeyboardKey.mediaTrackNext}):
          getActionIntent(HotkeysAction.mediaNext),
      LogicalKeySet.fromSet({LogicalKeyboardKey.mediaTrackPrevious}):
          getActionIntent(HotkeysAction.mediaPrevious),
      LogicalKeySet.fromSet({LogicalKeyboardKey.mediaStop}): getActionIntent(
        HotkeysAction.mediaStop,
      ),
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hotkeysActivatorProvider.overrideWithValue(activators),
          mprisManagerProvider.overrideWith(() => fake),
        ],
        child: const VeshellShortcutManager(
          child: Focus(autofocus: true, child: SizedBox()),
        ),
      ),
    );
    await tester.pump();
    expect(primaryFocus, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaTrackNext);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaTrackPrevious);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaStop);

    expect(fake.calls, ['playPause', 'next', 'previous', 'stop']);
  });
}
