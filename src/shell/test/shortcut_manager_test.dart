import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/screen/model/screen_manager_state.serializable.dart';
import 'package:shell/screen/provider/focused_screen.dart';
import 'package:shell/screen/provider/monitor_for_screen.dart';
import 'package:shell/screen/provider/pointer_screen.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/mpris/model/mpris_manager_state.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';
import 'package:shell/shared/mpris/provider/mpris_manager.dart';
import 'package:shell/shortcut_manager/model/media_intents.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';
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

/// A screen for the hotkey tests: it takes the keyboard while it is the
/// focused screen, as `ScreenWidget` does, and records the screen intents it
/// receives.
class _TestScreen extends HookConsumerWidget {
  const _TestScreen(this.screenId, this.received);

  final String screenId;
  final List<String> received;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = useFocusNode(debugLabel: 'screen $screenId');
    final isFocused = ref.watch(focusedScreenProvider) == screenId;
    useEffect(() {
      if (isFocused) {
        node.requestFocus();
      }
      return null;
    }, [isFocused]);
    void record(String name) => received.add('$name@$screenId');
    return CurrentScreenId(
      screenId: screenId,
      child: Actions(
        actions: {
          ToggleOverviewIntent: CallbackAction<ToggleOverviewIntent>(
            onInvoke: (_) => record('overview'),
          ),
          NavigateIntent: CallbackAction<NavigateIntent>(
            onInvoke: (_) => record('navigate'),
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => record('activate'),
          ),
        },
        child: Focus(focusNode: node, child: const SizedBox(height: 10)),
      ),
    );
  }
}

/// The screen holding the primary focus.
String? _focusedTestScreen() {
  final context = primaryFocus?.context;
  return context == null ? null : CurrentScreenId.maybeOf(context);
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
      const KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
      ),
    );
    dispatch(
      const KeyUpEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
        synthesized: true,
      ),
    );
    expect(overviewCount, 0);

    dispatch(
      const KeyDownEvent(
        physicalKey: physical,
        logicalKey: logical,
        timeStamp: Duration.zero,
      ),
    );
    dispatch(
      const KeyUpEvent(
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
              // In the shell every tile slot watches the grab, which keeps
              // it alive for the manager's reads.
              child: Consumer(
                builder: (context, ref, child) {
                  ref.watch(tileGrabControllerProvider);
                  return child!;
                },
                child: const Focus(autofocus: true, child: SizedBox()),
              ),
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

    testWidgets('the Super release after a pointer press neither opens the '
        'overview nor reaches the client', (tester) async {
      await pumpManager(tester);
      dispatch(superDown);
      final gesture = await tester.startGesture(
        const Offset(10, 10),
        kind: PointerDeviceKind.mouse,
      );
      grab.hold();
      await tester.pump();
      // The tile settles after the button is released, so the grab can end
      // before or after Super: neither order may toggle the overview.
      await gesture.up();
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

  testWidgets('Super hotkeys act on the screen under the pointer', (
    tester,
  ) async {
    final received = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hotkeysActivatorProvider.overrideWithValue({
            LogicalKeySet(
              LogicalKeyboardKey.superKey,
              LogicalKeyboardKey.arrowRight,
            ): const NavigateIntent(
              NavigationDirection.right,
            ),
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          }),
          screenManagerProvider.overrideWithValue(
            ScreenManagerState(screenIds: {'a', 'b'}.lock),
          ),
          // Two screens of one monitor: no compositor view to move.
          monitorForScreenProvider('a').overrideWithValue(null),
          monitorForScreenProvider('b').overrideWithValue(null),
        ],
        child: VeshellShortcutManager(
          child: Column(
            children: [_TestScreen('a', received), _TestScreen('b', received)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_focusedTestScreen(), 'a');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VeshellShortcutManager)),
    );

    void dispatchSuper({required bool down}) {
      final event = down
          ? const KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.metaLeft,
              logicalKey: LogicalKeyboardKey.superKey,
              timeStamp: Duration.zero,
            )
          : const KeyUpEvent(
              physicalKey: PhysicalKeyboardKey.metaLeft,
              logicalKey: LogicalKeyboardKey.superKey,
              timeStamp: Duration.zero,
            );
      HardwareKeyboard.instance.handleKeyEvent(event);
      ServicesBinding.instance.keyEventManager.keyMessageHandler!(
        KeyMessage([event], null),
      );
    }

    Future<void> pressSuper(LogicalKeyboardKey? key) async {
      dispatchSuper(down: true);
      if (key != null) {
        await simulateKeyDownEvent(key);
        await simulateKeyUpEvent(key);
      }
      dispatchSuper(down: false);
      await tester.pumpAndSettle();
    }

    // The keyboard is on screen a, the pointer on screen b: plain keys stay
    // with the focused widget.
    container.read(pointerScreenProvider.notifier).set('b');
    await simulateKeyDownEvent(LogicalKeyboardKey.enter);
    await simulateKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(received, ['activate@a']);
    expect(_focusedTestScreen(), 'a');

    // A Super chord acts on screen b, which takes the keyboard.
    await pressSuper(LogicalKeyboardKey.arrowRight);
    expect(received, ['activate@a', 'navigate@b']);
    expect(_focusedTestScreen(), 'b');

    // A Super tap opens the overview under the pointer, back on screen a.
    container.read(pointerScreenProvider.notifier).set('a');
    await pressSuper(null);
    expect(received, ['activate@a', 'navigate@b', 'overview@a']);
    expect(_focusedTestScreen(), 'a');
  });
}
