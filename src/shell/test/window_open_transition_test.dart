import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/provider/frozen_close_textures.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/window_close_requests.dart';
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
          // The first descendant is the close transition's own fade; the
          // frosted glass adds another, inner one for its grain.
          find.descendant(of: transition, matching: find.byType(Opacity)).first,
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

  testWidgets('a closed window paints its kept texture where it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 1000,
            height: 500,
            child: WindowCloseTransition(
              image: null,
              texture: (id: 7, rect: const Rect.fromLTWH(10, 20, 300, 200)),
              onDone: () {},
            ),
          ),
        ),
      ),
    );
    final transition = tester.getRect(find.byType(WindowCloseTransition));
    final texture = find.byType(Texture);
    expect(tester.widget<Texture>(texture).textureId, 7);
    expect(
      tester.getRect(texture),
      const Rect.fromLTWH(10, 20, 300, 200).shift(transition.topLeft),
    );
  });

  group('useWindowClosing', () {
    late WindowClosing? closing;
    late ProviderContainer container;
    late List<int> released;
    late List<(Size, bool)> closedLayouts;
    final frameKey = GlobalKey();
    const tile = PersistentWindowId('tile');

    setUp(() {
      container = ProviderContainer();
      released = [];
      closedLayouts = [];
    });
    tearDown(() => container.dispose());

    void request() =>
        container.read(windowCloseRequestsProvider(tile).notifier).request();

    Future<void> build(
      WidgetTester tester, {
      required String? metaWindowId,
      bool enabled = true,
    }) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HookConsumer(
            builder: (context, ref, child) {
              closing = useWindowClosing(
                ref: ref,
                windowId: tile,
                metaWindowId: metaWindowId,
                closeRequests: ref.watch(windowCloseRequestsProvider(tile)),
                frameKey: frameKey,
                enabled: enabled,
                windowTextureId: () => 7,
                releaseTexture: released.add,
                onWindowClosed: (size, fullBleed) =>
                    closedLayouts.add((size, fullBleed)),
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
      ),
    );

    testWidgets('a window closed by the shell wraps up with its last frame', (
      tester,
    ) async {
      await build(tester, metaWindowId: 'a');
      expect(closing, isNull);
      // The request captures the frame before it reaches the client, so the
      // window can be gone by the time the next frame builds.
      request();
      await tester.pump();
      // Asked to close, but not closed yet: nothing plays.
      expect(closing, isNull);

      await build(tester, metaWindowId: null);
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
      await build(tester, metaWindowId: 'a');
      request();
      await build(tester, metaWindowId: null);
      final started = closing!;
      expect(started.texture?.id, 7);
      expect(started.texture?.rect, const Rect.fromLTRB(10, 20, 770, 560));
      expect(released, isEmpty);

      started.done();
      await tester.pump();
      expect(released, [7]);
    });

    testWidgets('the frozen copy of a requested close replaces the live '
        'texture, and both are released', (tester) async {
      await build(tester, metaWindowId: 'a');
      request();
      // The compositor answered the close request with its copy.
      container.read(frozenCloseTexturesProvider.notifier).put('a', 42);
      await build(tester, metaWindowId: null);
      final started = closing!;
      expect(started.texture?.id, 42);
      // Painted where the live texture was.
      expect(started.texture?.rect, const Rect.fromLTRB(10, 20, 770, 560));
      // Taken once.
      expect(
        container.read(frozenCloseTexturesProvider.notifier).take('a'),
        isNull,
      );

      started.done();
      await tester.pump();
      expect(released, unorderedEquals([7, 42]));
    });

    testWidgets('a closed window reports its layout once', (tester) async {
      await build(tester, metaWindowId: 'a');
      await tester.pump();
      await build(tester, metaWindowId: null);
      expect(closedLayouts, hasLength(1));
      // The texture's rect: the test window has no geometry.
      expect(closedLayouts.single.$1, const Size(760, 540));
      expect(closedLayouts.single.$2, isFalse);
      await build(tester, metaWindowId: null);
      expect(closedLayouts, hasLength(1));
    });

    testWidgets('a window closing on its own keeps its last texture', (
      tester,
    ) async {
      await build(tester, metaWindowId: 'a');
      // The texture is remembered after the frame it was painted in.
      await tester.pump();
      await build(tester, metaWindowId: null);
      expect(closing, isNotNull);
      // The shell never captured a frame for a close it did not request, but
      // the compositor retained the window's texture and the closing still
      // shows it over a plain surface.
      expect(closing!.image, isNull);
      expect(closing!.texture?.id, 7);
    });

    testWidgets('a window shown again cancels the closing', (tester) async {
      await build(tester, metaWindowId: 'a');
      request();
      await build(tester, metaWindowId: null);
      final image = closing!.image!;
      await build(tester, metaWindowId: 'b');
      expect(closing, isNull);
      await tester.pump();
      expect(image.debugDisposed, isTrue);
    });

    testWidgets('a frame captured for another window is not used', (
      tester,
    ) async {
      await build(tester, metaWindowId: 'a');
      request();
      await build(tester, metaWindowId: 'b');
      await build(tester, metaWindowId: null);
      expect(closing, isNotNull);
      // The close request captured 'a', not the window that closed.
      expect(closing!.image, isNull);
      // 'b' was still live, so its own remembered texture is shown.
      expect(closing!.texture?.id, 7);
    });

    testWidgets('nothing plays when disabled', (tester) async {
      await build(tester, metaWindowId: 'a', enabled: false);
      request();
      await build(tester, metaWindowId: null, enabled: false);
      expect(closing, isNull);
    });
  });
}
