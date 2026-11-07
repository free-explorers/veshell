import 'dart:ui' as ui;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/window/widget/window_open_transition.dart';
import 'package:shell/window/widget/window_placeholder.dart';

class _Stateful extends StatefulWidget {
  const _Stateful();

  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  testWidgets('the placeholder card opens onto the window behind it', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: windowOpenTransitionDuration,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 1000,
          height: 500,
          child: WindowOpenTransition(
            animation: controller,
            child: const _Stateful(),
          ),
        ),
      ),
    );

    final tileRect = tester.getRect(find.byType(WindowOpenTransition));
    final tileSize = tileRect.size;
    Rect openingRect() => tester
        .widget<ClipRRect>(find.byType(ClipRRect))
        .clipper!
        .getClip(tileSize)
        .outerRect;

    // At the start the opening is exactly the placeholder's card.
    expect(
      openingRect(),
      Rect.fromLTRB(
        tileSize.width * placeholderCardInset,
        tileSize.height * placeholderCardInset,
        tileSize.width * (1 - placeholderCardInset),
        tileSize.height * (1 - placeholderCardInset),
      ),
    );
    // The window itself never moves: it fills the tile from the start.
    expect(tester.getRect(find.byType(_Stateful)), tileRect);

    final stateBefore = tester.state(find.byType(_Stateful));
    controller.value = 0.5;
    await tester.pump();
    expect(tester.getRect(find.byType(_Stateful)), tileRect);

    controller.value = 1;
    await tester.pump();
    expect(openingRect(), Offset.zero & tileSize);
    // Settling must not remount the window.
    expect(tester.state(find.byType(_Stateful)), same(stateBefore));

    // The outgoing window of a close is not shrunk by the switcher (its
    // surface is gone): `WindowCloseTransition` plays the closing instead.
    controller.reverse();
    await tester.pump();
    await tester.pump(windowOpenTransitionDuration ~/ 2);
    expect(openingRect(), Offset.zero & tileSize);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('only a launch plays the opening, not a window swap', (
    tester,
  ) async {
    Key? key;
    Future<void> build({required bool hasWindow, bool launching = false}) =>
        tester.pumpWidget(
          HookBuilder(
            builder: (context) {
              key = useWindowSwitcherKey(
                hasWindow: hasWindow,
                launching: launching,
              );
              return const SizedBox();
            },
          ),
        );

    // A launch from the placeholder keeps the switcher, so it animates.
    await build(hasWindow: false);
    final initial = key;
    await build(hasWindow: false, launching: true);
    await build(hasWindow: true);
    expect(key, initial);

    // Closing keeps it too: the placeholder fades in over the window.
    await build(hasWindow: false);
    expect(key, initial);

    // A window that shows up with no launch pending is a swap: the switcher
    // is remounted and shows it at once.
    await build(hasWindow: true);
    final swapped = key;
    expect(swapped, isNot(initial));

    // Further updates of the shown window keep the switcher.
    await build(hasWindow: true);
    expect(key, swapped);
  });

  testWidgets('a closed window wraps back into the placeholder card', (
    tester,
  ) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1000,
            height: 500,
            child: WindowCloseTransition(
              image: null,
              onDone: () => done = true,
            ),
          ),
        ),
      ),
    );
    final tileRect = tester.getRect(find.byType(WindowCloseTransition));
    final tileSize = tileRect.size;
    final transition = find.byType(WindowCloseTransition);
    Rect openingRect() => tester
        .widget<ClipRRect>(
          find.descendant(of: transition, matching: find.byType(ClipRRect)),
        )
        .clipper!
        .getClip(tileSize)
        .outerRect;
    double opacity() => tester
        .widget<Opacity>(
          find.descendant(of: transition, matching: find.byType(Opacity)),
        )
        .opacity;
    final card = Rect.fromLTRB(
      tileSize.width * placeholderCardInset,
      tileSize.height * placeholderCardInset,
      tileSize.width * (1 - placeholderCardInset),
      tileSize.height * (1 - placeholderCardInset),
    );

    // It starts as the whole window…
    expect(openingRect(), Offset.zero & tileSize);
    expect(opacity(), 1);

    // …narrows towards the card…
    await tester.pump(windowOpenTransitionDuration * 0.4);
    final mid = openingRect();
    expect(mid.width, lessThan(tileSize.width));
    expect(mid.width, greaterThan(card.width));
    expect(opacity(), 1);

    // …is the card, and fades out into it.
    await tester.pump(windowOpenTransitionDuration * 0.5);
    expect(openingRect().left, closeTo(card.left, 1));
    expect(openingRect().width, closeTo(card.width, 2));
    expect(opacity(), lessThan(1));
    expect(done, isFalse);

    await tester.pumpAndSettle();
    expect(opacity(), 0);
    expect(done, isTrue);
  });

  group('useWindowClosing', () {
    late WindowClosing? closing;
    final frameKey = GlobalKey();

    Future<void> build(
      WidgetTester tester, {
      required String? metaWindowId,
      int closeRequests = 0,
      bool enabled = true,
    }) => tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            closing = useWindowClosing(
              metaWindowId: metaWindowId,
              closeRequests: closeRequests,
              frameKey: frameKey,
              enabled: enabled,
            );
            return RepaintBoundary(
              key: frameKey,
              child: const ColoredBox(color: Colors.red),
            );
          },
        ),
      ),
    );

    testWidgets('a window closed by the shell wraps up with its last frame', (
      tester,
    ) async {
      await build(tester, metaWindowId: 'a');
      expect(closing, isNull);
      await build(tester, metaWindowId: 'a', closeRequests: 1);
      // Asked to close, but not closed yet: nothing plays.
      await tester.pump();
      expect(closing, isNull);

      await build(tester, metaWindowId: null, closeRequests: 1);
      final started = closing!;
      final image = started.image!;
      // At the screen's resolution.
      final ratio = tester.view.devicePixelRatio;
      expect((image.width, image.height), (800 * ratio, 600 * ratio));

      started.done();
      await tester.pump();
      expect(closing, isNull);
      // The frame is released once no longer painted.
      expect(image.debugDisposed, isTrue);
    });

    testWidgets("the window's kept texture is placed and released", (
      tester,
    ) async {
      final released = <int>[];
      Future<void> pump({required String? metaWindowId}) => tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              closing = useWindowClosing(
                metaWindowId: metaWindowId,
                closeRequests: 1,
                frameKey: frameKey,
                enabled: true,
                windowTextureId: () => 7,
                releaseTexture: released.add,
              );
              return RepaintBoundary(
                key: frameKey,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(10, 20, 30, 40),
                  child: Texture(textureId: 7),
                ),
              );
            },
          ),
        ),
      );

      await pump(metaWindowId: 'a');
      await pump(metaWindowId: null);
      final started = closing!;
      expect(started.texture?.id, 7);
      expect(started.texture?.rect, const Rect.fromLTRB(10, 20, 770, 560));
      expect(released, isEmpty);

      started.done();
      await tester.pump();
      expect(released, [7]);
    });

    testWidgets('a window closing on its own wraps up without a frame', (
      tester,
    ) async {
      await build(tester, metaWindowId: 'a');
      await build(tester, metaWindowId: null);
      expect(closing, isNotNull);
      expect(closing!.image, isNull);
    });

    testWidgets('a window shown again cancels the closing', (tester) async {
      await build(tester, metaWindowId: 'a', closeRequests: 1);
      await build(tester, metaWindowId: null, closeRequests: 1);
      final image = closing!.image!;
      await build(tester, metaWindowId: 'b', closeRequests: 1);
      expect(closing, isNull);
      await tester.pump();
      expect(image.debugDisposed, isTrue);
    });

    testWidgets('a frame captured for another window is not used', (
      tester,
    ) async {
      await build(tester, metaWindowId: 'a', closeRequests: 1);
      await build(tester, metaWindowId: 'b', closeRequests: 1);
      await build(tester, metaWindowId: null, closeRequests: 1);
      expect(closing, isNotNull);
      expect(closing!.image, isNull);
    });

    testWidgets('nothing plays when disabled', (tester) async {
      await build(tester, metaWindowId: 'a', closeRequests: 1, enabled: false);
      await build(tester, metaWindowId: null, closeRequests: 1, enabled: false);
      expect(closing, isNull);
    });
  });
}
