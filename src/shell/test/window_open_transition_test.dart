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

    // Closing does not shrink the opening back: the window stays whole and
    // opaque while the placeholder fades in over it.
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
}
