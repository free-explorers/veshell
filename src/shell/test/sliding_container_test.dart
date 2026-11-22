// The ProviderScope a helper builds here is the root scope handed to
// pumpWidget; the lint only recognises a root scope written inline there.
// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/platform/model/event/gesture_swipe/gesture_swipe_begin.serializable.dart';
import 'package:shell/platform/model/event/gesture_swipe/gesture_swipe_end.serializable.dart';
import 'package:shell/platform/model/event/gesture_swipe/gesture_swipe_update.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/sliding_container.dart';

/// The container's pages: the scrollable a `PageView` would build.
final Finder _pages = find.descendant(
  of: find.byType(SlidingContainer),
  matching: find.byType(Scrollable),
);

/// Renders a [SlidingContainer] in a fixed viewport and returns the size of the
/// page view it laid out.
Future<Size> _pageViewSize(
  WidgetTester tester, {
  required double width,
  required int visible,
}) async {
  final events = StreamController<PlatformEvent>.broadcast();
  addTearDown(events.close);
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = Size(width, 600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [platformManagerProvider.overrideWithValue(events.stream)],
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            height: 100,
            child: SlidingContainer(
              index: 0,
              visible: visible,
              children: const [SizedBox(), SizedBox(), SizedBox(), SizedBox()],
            ),
          ),
        ),
      ),
    ),
  );
  return tester.getSize(_pages);
}

/// Renders a [SlidingContainer] and returns the page it settled on, i.e. the
/// index of the leading (leftmost) tile it shows.
Future<double?> _leadingPage(
  WidgetTester tester, {
  required double width,
  required int visible,
  required int index,
  int? firstVisibleIndex,
  void Function(int newFirstVisibleIndex)? onFirstVisibleIndexChanged,
}) async {
  final events = StreamController<PlatformEvent>.broadcast();
  addTearDown(events.close);
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = Size(width, 600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [platformManagerProvider.overrideWithValue(events.stream)],
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            height: 100,
            child: SlidingContainer(
              index: index,
              visible: visible,
              firstVisibleIndex: firstVisibleIndex,
              onFirstVisibleIndexChanged: onFirstVisibleIndexChanged,
              children: const [SizedBox(), SizedBox(), SizedBox(), SizedBox()],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (tester.widget<Scrollable>(_pages).controller! as PageController).page;
}

/// Renders a [SlidingContainer] whose page count can change, in a fixed
/// viewport of 600x100 logical pixels.
Future<void> _pumpResizable(
  WidgetTester tester, {
  required ValueNotifier<int> visible,
  required List<Widget> children,
}) async {
  final events = StreamController<PlatformEvent>.broadcast();
  addTearDown(events.close);
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(600, 100);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [platformManagerProvider.overrideWithValue(events.stream)],
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: 600,
            height: 100,
            child: ValueListenableBuilder<int>(
              valueListenable: visible,
              builder: (context, count, _) => SlidingContainer(
                index: 0,
                visible: count,
                children: children,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Emits the compositor's three-finger swipe events into [events].
void _swipeBegin(StreamController<PlatformEvent> events, {int fingers = 3}) {
  events.add(
    GestureSwipeBeginEvent(
      method: 'gesture_swipe_begin',
      message: GestureSwipeBeginMessage(time: 0, fingers: fingers),
    ),
  );
}

void _swipeUpdate(
  StreamController<PlatformEvent> events, {
  required double dx,
  required double dy,
  required int time,
  int fingers = 3,
}) {
  events.add(
    GestureSwipeUpdateEvent(
      method: 'gesture_swipe_update',
      message: GestureSwipeUpdateMessage(
        time: time,
        fingers: fingers,
        deltaX: dx,
        deltaY: dy,
      ),
    ),
  );
}

void _swipeEnd(
  StreamController<PlatformEvent> events, {
  required int time,
  bool cancelled = false,
  int fingers = 3,
}) {
  events.add(
    GestureSwipeEndEvent(
      method: 'gesture_swipe_end',
      message: GestureSwipeEndMessage(
        time: time,
        fingers: fingers,
        cancelled: cancelled,
      ),
    ),
  );
}

/// Emits [count] horizontal updates of [dx] gesture units, [intervalMs] apart.
void _swipeSteps(
  StreamController<PlatformEvent> events, {
  required double dx,
  required int count,
  required int intervalMs,
  int startTime = 0,
}) {
  for (var i = 0; i < count; i++) {
    _swipeUpdate(events, dx: dx, dy: 0, time: startTime + i * intervalMs);
  }
}

/// The (fractional) page the container's row currently shows.
double? _page(WidgetTester tester, {Finder? container}) {
  final finder = find.descendant(
    of: container ?? find.byType(SlidingContainer),
    matching: find.byType(Scrollable),
  );
  return (tester.widget<Scrollable>(finder).controller! as PageController).page;
}

class _SwipeHarness {
  _SwipeHarness(this.events, this.picked, this.selected);
  final StreamController<PlatformEvent> events;
  final List<int> picked;
  final ValueNotifier<int> selected;
}

/// Renders a [SlidingContainer] wired to a controllable platform stream, with
/// its selected index fed back so a swipe navigates as it does in the shell.
Future<_SwipeHarness> _pumpSwipeContainer(
  WidgetTester tester, {
  required int visible,
  int index = 0,
  int? firstVisibleIndex,
  Axis direction = Axis.horizontal,
  double width = 600,
}) async {
  final events = StreamController<PlatformEvent>.broadcast();
  addTearDown(events.close);
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = Size(width, 600);
  addTearDown(tester.view.reset);
  final picked = <int>[];
  final selected = ValueNotifier(index);
  addTearDown(selected.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [platformManagerProvider.overrideWithValue(events.stream)],
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: width,
            height: 100,
            child: ValueListenableBuilder<int>(
              valueListenable: selected,
              builder: (context, value, _) => SlidingContainer(
                direction: direction,
                index: value,
                visible: visible,
                firstVisibleIndex: firstVisibleIndex,
                onIndexChanged: (next) {
                  picked.add(next);
                  selected.value = next;
                },
                children: const [
                  SizedBox(),
                  SizedBox(),
                  SizedBox(),
                  SizedBox(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _SwipeHarness(events, picked, selected);
}

void main() {
  testWidgets(
    'a viewport not divisible by the visible tiles snaps to whole pages',
    (tester) async {
      // 2464 / 3 = 821.33 would start the second and third tiles on a
      // fractional logical pixel, softening every live surface on them.
      final size = await _pageViewSize(tester, width: 2464, visible: 3);
      expect(size.width, 2463);
    },
  );

  testWidgets('a divisible viewport is left untouched', (tester) async {
    final size = await _pageViewSize(tester, width: 2464, visible: 2);
    expect(size.width, 2464);
  });

  testWidgets('a single visible tile keeps the full viewport', (tester) async {
    final size = await _pageViewSize(tester, width: 2464, visible: 1);
    expect(size.width, 2464);
  });

  testWidgets(
    'restores the leading tile instead of anchoring the selected one',
    (tester) async {
      // A workspace with two windows and the launcher selected tile 2 leaves
      // the view on tiles [0, 1]. Rebuilding the container (e.g. after a round
      // trip through another workspace) must keep that view rather than start
      // the selected tile at the leading edge.
      final page = await _leadingPage(
        tester,
        width: 400,
        visible: 2,
        index: 1,
        firstVisibleIndex: 0,
      );
      expect(page, 0);
    },
  );

  testWidgets(
    'scrolls a selected tile outside the restored view back into view',
    (tester) async {
      final reported = <int>[];
      final page = await _leadingPage(
        tester,
        width: 400,
        visible: 2,
        index: 2,
        firstVisibleIndex: 0,
        onFirstVisibleIndexChanged: reported.add,
      );
      // Selecting the launcher shows the previous window plus the launcher.
      expect(page, 1);
      expect(reported.last, 1);
    },
  );

  testWidgets('a keyed page keeps its state when it moves to another index', (
    tester,
  ) async {
    final events = StreamController<PlatformEvent>.broadcast();
    addTearDown(events.close);
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(600, 100);
    addTearDown(tester.view.reset);
    Widget pages(List<String> order) => ProviderScope(
      overrides: [platformManagerProvider.overrideWithValue(events.stream)],
      child: MaterialApp(
        home: SlidingContainer(
          index: 0,
          visible: 2,
          children: [
            for (final id in order) _StatefulPage(key: ValueKey(id), id: id),
          ],
        ),
      ),
    );
    await tester.pumpWidget(pages(['a', 'b']));
    final stateOfA = tester.state(find.byKey(const ValueKey('a')));

    await tester.pumpWidget(pages(['b', 'a']));

    expect(tester.state(find.byKey(const ValueKey('a'))), same(stateOfA));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('a'))).dx,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('b'))).dx),
    );
  });

  group('a page left and then shown again', () {
    testWidgets('is reused when pages are kept alive', (tester) async {
      final events = StreamController<PlatformEvent>.broadcast();
      addTearDown(events.close);
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(600, 100);
      addTearDown(tester.view.reset);
      Widget pagesAt(int index) => ProviderScope(
        overrides: [platformManagerProvider.overrideWithValue(events.stream)],
        child: MaterialApp(
          home: SlidingContainer(
            index: index,
            keepsPagesAlive: true,
            children: const [
              _StatefulPage(key: ValueKey('a'), id: 'a'),
              _StatefulPage(key: ValueKey('b'), id: 'b'),
              _StatefulPage(key: ValueKey('c'), id: 'c'),
            ],
          ),
        ),
      );
      final page = find.byWidgetPredicate(
        (widget) => widget is _StatefulPage && widget.id == 'a',
        skipOffstage: false,
      );
      await tester.pumpWidget(pagesAt(0));
      final before = tester.state(page);

      await tester.pumpWidget(pagesAt(2));
      await tester.pumpAndSettle();
      // Off screen, it is kept rather than disposed.
      expect(tester.state(page), same(before));

      await tester.pumpWidget(pagesAt(0));
      await tester.pumpAndSettle();
      expect(tester.state(page), same(before));
      expect(find.text('a'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('is built again otherwise', (tester) async {
      final events = StreamController<PlatformEvent>.broadcast();
      addTearDown(events.close);
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(600, 100);
      addTearDown(tester.view.reset);
      Widget pagesAt(int index) => ProviderScope(
        overrides: [platformManagerProvider.overrideWithValue(events.stream)],
        child: MaterialApp(
          home: SlidingContainer(
            index: index,
            children: const [
              _StatefulPage(key: ValueKey('a'), id: 'a'),
              _StatefulPage(key: ValueKey('b'), id: 'b'),
              _StatefulPage(key: ValueKey('c'), id: 'c'),
            ],
          ),
        ),
      );
      final page = find.byWidgetPredicate(
        (widget) => widget is _StatefulPage && widget.id == 'a',
        skipOffstage: false,
      );
      await tester.pumpWidget(pagesAt(0));
      final before = tester.state(page);

      await tester.pumpWidget(pagesAt(2));
      await tester.pumpAndSettle();
      expect(page, findsNothing);

      await tester.pumpWidget(pagesAt(0));
      await tester.pumpAndSettle();
      expect(tester.state(page), isNot(same(before)));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('changing the page count resizes the tiles from their old size', (
    tester,
  ) async {
    final visible = ValueNotifier(1);
    addTearDown(visible.dispose);
    await _pumpResizable(
      tester,
      visible: visible,
      children: const [
        SizedBox(key: ValueKey('page-0')),
        SizedBox(key: ValueKey('page-1')),
      ],
    );
    await tester.pumpAndSettle();

    final page = find.byKey(const ValueKey('page-0'));
    expect(tester.getSize(page).width, 600);

    visible.value = 2;
    await tester.pump();

    // One page used to fill the row; the first frame of the transition still
    // lays it out at that old size, not the new half.
    expect(tester.getSize(page).width, 600);

    // The controller starts in a post-frame callback, so its first tick only
    // marks the start; the next one, half the 120 ms duration later, must
    // already show the page partway to its new size.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getSize(page).width, inExclusiveRange(300.0, 600.0));

    await tester.pumpAndSettle();
    expect(tester.getSize(page).width, 300);
  });

  testWidgets('a tile leaving the view stays built until it has slid out', (
    tester,
  ) async {
    final visible = ValueNotifier(3);
    addTearDown(visible.dispose);
    await _pumpResizable(
      tester,
      visible: visible,
      children: const [
        _StatefulPage(key: ValueKey('page-0'), id: '0'),
        _StatefulPage(key: ValueKey('page-1'), id: '1'),
        _StatefulPage(key: ValueKey('page-2'), id: '2'),
        _StatefulPage(key: ValueKey('page-3'), id: '3'),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('page-3'), skipOffstage: false),
      findsNothing,
    );
    final stateOfLeavingPage = tester.state(
      find.byKey(const ValueKey('page-2'), skipOffstage: false),
    );

    visible.value = 1;
    await tester.pump();

    // The leaving tile starts in view and must stay mounted while it slides
    // out. Off-view sliver children are offstage to finders, so look for them
    // explicitly.
    expect(
      tester.state(find.byKey(const ValueKey('page-2'), skipOffstage: false)),
      same(stateOfLeavingPage),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.state(find.byKey(const ValueKey('page-2'), skipOffstage: false)),
      same(stateOfLeavingPage),
    );

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('page-2'), skipOffstage: false),
      findsNothing,
    );
  });

  group('three-finger swipe', () {
    testWidgets('a slow drag past half a page moves one tile', (tester) async {
      final harness = await _pumpSwipeContainer(tester, visible: 1);
      _swipeBegin(harness.events);
      // 240 gesture units = 0.6 of the 400-unit horizontal page, dragged
      // slowly enough that the release has no fling left.
      _swipeSteps(harness.events, dx: 40, count: 6, intervalMs: 100);
      _swipeEnd(harness.events, time: 600);
      await tester.pumpAndSettle();
      // Let the cursor transition's settle timer fire before the test ends.
      await tester.pump(const Duration(milliseconds: 150));

      expect(harness.picked, [1]);
      expect(harness.selected.value, 1);
      expect(_page(tester), 1);
    });

    testWidgets('a short fast flick moves one tile', (tester) async {
      final harness = await _pumpSwipeContainer(tester, visible: 1);
      _swipeBegin(harness.events);
      // 0.4 of a page, but released while still moving: the projected
      // deceleration carries it past the next page.
      _swipeSteps(harness.events, dx: 40, count: 4, intervalMs: 8);
      _swipeEnd(harness.events, time: 32);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 150));

      expect(harness.picked, [1]);
      expect(_page(tester), 1);
    });

    testWidgets('a slow drag below half a page snaps back', (tester) async {
      final harness = await _pumpSwipeContainer(tester, visible: 1);
      _swipeBegin(harness.events);
      _swipeSteps(harness.events, dx: 40, count: 3, intervalMs: 100);
      _swipeEnd(harness.events, time: 300);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 150));

      expect(harness.picked, isEmpty);
      expect(_page(tester), 0);
    });

    testWidgets('a pause before lifting decays the fling', (tester) async {
      // The same gesture as the fast flick, but the fingers rest for more
      // than the 150 ms velocity window before lifting: no fling is left.
      final harness = await _pumpSwipeContainer(tester, visible: 1);
      _swipeBegin(harness.events);
      _swipeSteps(harness.events, dx: 40, count: 4, intervalMs: 8);
      _swipeEnd(harness.events, time: 400);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 150));

      expect(harness.picked, isEmpty);
      expect(_page(tester), 0);
    });

    testWidgets('a backwards swipe from the first tile does not move forward', (
      tester,
    ) async {
      // Regression: the old end-of-gesture logic compared the viewport-centre
      // page with the selected tile, so with two tiles visible a backwards
      // swipe selected the next tile.
      final harness = await _pumpSwipeContainer(
        tester,
        visible: 2,
        firstVisibleIndex: 0,
      );
      _swipeBegin(harness.events);
      _swipeUpdate(harness.events, dx: -200, dy: 0, time: 0);
      _swipeUpdate(harness.events, dx: -200, dy: 0, time: 16);
      _swipeEnd(harness.events, time: 32);
      await tester.pumpAndSettle();

      expect(harness.picked, isEmpty);
      expect(_page(tester), 0);
    });

    testWidgets('a cancelled swipe snaps back without changing the tile', (
      tester,
    ) async {
      final harness = await _pumpSwipeContainer(tester, visible: 1);
      _swipeBegin(harness.events);
      _swipeSteps(harness.events, dx: 40, count: 6, intervalMs: 16);
      _swipeEnd(harness.events, time: 100, cancelled: true);
      await tester.pumpAndSettle();
      // Let the cursor transition's settle timer fire before the test ends.
      await tester.pump(const Duration(milliseconds: 150));

      expect(harness.picked, isEmpty);
      expect(harness.selected.value, 0);
      expect(_page(tester), 0);
    });

    testWidgets(
      'a cancelled drag past half a page still returns to its start',
      (tester) async {
        // With two tiles visible the selected trailing tile stays in view, so
        // restoring it would only snap to the *nearest* page. A cancelled
        // gesture must return to the page it started on, not advance one.
        final harness = await _pumpSwipeContainer(
          tester,
          visible: 2,
          index: 1,
          firstVisibleIndex: 0,
        );
        _swipeBegin(harness.events);
        _swipeSteps(harness.events, dx: 40, count: 6, intervalMs: 16);
        _swipeEnd(harness.events, time: 100, cancelled: true);
        await tester.pumpAndSettle();
        // Let the cursor transition's settle timer fire before the test ends.
        await tester.pump(const Duration(milliseconds: 150));

        expect(harness.picked, isEmpty);
        expect(_page(tester), 0);
      },
    );

    testWidgets('a short swipe settles on whole pages with several tiles', (
      tester,
    ) async {
      // The selected tile is the trailing visible one, so the selection can
      // stay in view without the row moving. A drag below half a page of
      // normalized progress must neither pick the next tile nor leave the row
      // between slots.
      final harness = await _pumpSwipeContainer(
        tester,
        visible: 2,
        index: 1,
        firstVisibleIndex: 0,
      );
      _swipeBegin(harness.events);
      _swipeUpdate(harness.events, dx: 10, dy: 0, time: 0);
      _swipeUpdate(harness.events, dx: 20, dy: 0, time: 100);
      _swipeUpdate(harness.events, dx: 20, dy: 0, time: 200);
      _swipeEnd(harness.events, time: 300);
      await tester.pumpAndSettle();
      // Let the cursor transition's settle timer fire before the test ends.
      await tester.pump(const Duration(milliseconds: 150));

      expect(harness.picked, isEmpty);
      expect(_page(tester), 0);
    });

    testWidgets('the row follows the normalized progress, not the page width', (
      tester,
    ) async {
      // 200 units is half of the 400-unit horizontal page, so the row must be
      // halfway across, whatever the page is wide.
      final harness = await _pumpSwipeContainer(
        tester,
        visible: 1,
        width: 2000,
      );
      _swipeBegin(harness.events);
      _swipeSteps(harness.events, dx: 100, count: 2, intervalMs: 100);
      await tester.pump();

      expect(_page(tester), closeTo(0.5, 0.01));

      _swipeEnd(harness.events, time: 200);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('a wide tile follows the same normalized swipe distance', (
      tester,
    ) async {
      // The same 240 gestures units that move a 600 px page also move a
      // 2000 px tile: the page width does not change the gesture travel.
      final harness = await _pumpSwipeContainer(
        tester,
        visible: 1,
        width: 2000,
      );
      _swipeBegin(harness.events);
      _swipeSteps(harness.events, dx: 40, count: 6, intervalMs: 100);
      _swipeEnd(harness.events, time: 600);
      await tester.pumpAndSettle();
      // Let the cursor transition's settle timer fire before the test ends.
      await tester.pump(const Duration(milliseconds: 150));

      expect(harness.picked, [1]);
      expect(_page(tester), 1);
    });

    testWidgets('a slow wide-tile drag below half a page snaps back', (
      tester,
    ) async {
      final harness = await _pumpSwipeContainer(
        tester,
        visible: 1,
        width: 2000,
      );
      _swipeBegin(harness.events);
      _swipeSteps(harness.events, dx: 40, count: 3, intervalMs: 100);
      _swipeEnd(harness.events, time: 300);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 150));

      expect(harness.picked, isEmpty);
      expect(_page(tester), 0);
    });

    testWidgets(
      'a gesture cut off by a disabled detector does not wedge the row',
      (tester) async {
        // The detector unsubscribes while `isSwipeEnabled` is false, so a
        // gesture in progress never delivers its end. Its state must be reset:
        // a stale `swipeInProgress` makes `scrollToIndex` refuse to settle the
        // next selection, leaving the row between two pages.
        final events = StreamController<PlatformEvent>.broadcast();
        addTearDown(events.close);
        tester.view
          ..devicePixelRatio = 1.0
          ..physicalSize = const Size(600, 600);
        addTearDown(tester.view.reset);
        final enabled = ValueNotifier(true);
        final selected = ValueNotifier(1);
        final firstVisible = ValueNotifier(0);
        addTearDown(enabled.dispose);
        addTearDown(selected.dispose);
        addTearDown(firstVisible.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              platformManagerProvider.overrideWithValue(events.stream),
            ],
            child: MaterialApp(
              home: Center(
                child: SizedBox(
                  width: 600,
                  height: 100,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      enabled,
                      selected,
                      firstVisible,
                    ]),
                    builder: (context, _) => SlidingContainer(
                      index: selected.value,
                      visible: 2,
                      firstVisibleIndex: firstVisible.value,
                      isSwipeEnabled: enabled.value,
                      onIndexChanged: (next) => selected.value = next,
                      onFirstVisibleIndexChanged: (next) =>
                          firstVisible.value = next,
                      children: const [
                        SizedBox(),
                        SizedBox(),
                        SizedBox(),
                        SizedBox(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Leave the row partway between pages without an end event.
        _swipeBegin(events);
        _swipeUpdate(events, dx: 40, dy: 0, time: 0);
        _swipeUpdate(events, dx: 40, dy: 0, time: 100);
        _swipeUpdate(events, dx: 40, dy: 0, time: 200);
        enabled.value = false;
        await tester.pumpAndSettle();

        // Re-enable and select another tile: the row must land on a whole page.
        enabled.value = true;
        selected.value = 2;
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 150));

        expect(selected.value, 2);
        expect(_page(tester), 1);
        expect(firstVisible.value, 1);
      },
    );

    testWidgets(
      'a tile removed before the view mid-swipe keeps the row on the selection',
      (tester) async {
        // The caller moves the leading tile while the row is between two
        // pages. The shift must still be applied, with the gesture's origin,
        // or the cancelled swipe returns to the old offset, which now shows
        // the tiles one slot further.
        final events = StreamController<PlatformEvent>.broadcast();
        addTearDown(events.close);
        tester.view
          ..devicePixelRatio = 1.0
          ..physicalSize = const Size(600, 600);
        addTearDown(tester.view.reset);
        final tiles = ValueNotifier([0, 1, 2, 3, 4]);
        final selected = ValueNotifier(3);
        final firstVisible = ValueNotifier(2);
        addTearDown(tiles.dispose);
        addTearDown(selected.dispose);
        addTearDown(firstVisible.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              platformManagerProvider.overrideWithValue(events.stream),
            ],
            child: MaterialApp(
              home: Center(
                child: SizedBox(
                  width: 600,
                  height: 100,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      tiles,
                      selected,
                      firstVisible,
                    ]),
                    builder: (context, _) => SlidingContainer(
                      index: selected.value,
                      visible: 2,
                      firstVisibleIndex: firstVisible.value,
                      onIndexChanged: (next) => selected.value = next,
                      onFirstVisibleIndexChanged: (next) =>
                          firstVisible.value = next,
                      children: [
                        for (final tile in tiles.value)
                          SizedBox(key: ValueKey(tile)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_page(tester), 2);

        // Leave the row partway between pages.
        _swipeBegin(events);
        _swipeUpdate(events, dx: 40, dy: 0, time: 0);
        _swipeUpdate(events, dx: 40, dy: 0, time: 100);
        await tester.pump();
        expect(_page(tester), isNot(2));

        // Tile 0 closes: every index shifts down by one, as the shell does.
        tiles.value = [1, 2, 3, 4];
        selected.value = 2;
        firstVisible.value = 1;
        await tester.pump();

        _swipeEnd(events, time: 200, cancelled: true);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 150));

        // Back on the tiles the gesture started from, now at index 1.
        expect(selected.value, 2);
        expect(_page(tester), 1);
        expect(firstVisible.value, 1);
      },
    );

    /// Renders the two rows a swipe can reach: the tile row and, below it, the
    /// screen's workspace row, both listening to [events].
    Future<(List<int>, List<int>)> pumpBothRows(
      WidgetTester tester,
      StreamController<PlatformEvent> events,
    ) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(600, 600);
      addTearDown(tester.view.reset);
      final horizontal = <int>[];
      final vertical = <int>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [platformManagerProvider.overrideWithValue(events.stream)],
          child: MaterialApp(
            home: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const ValueKey('horizontal'),
                  height: 100,
                  child: SlidingContainer(
                    index: 0,
                    onIndexChanged: horizontal.add,
                    children: const [SizedBox(), SizedBox(), SizedBox()],
                  ),
                ),
                SizedBox(
                  key: const ValueKey('vertical'),
                  height: 100,
                  child: SlidingContainer(
                    direction: Axis.vertical,
                    index: 0,
                    onIndexChanged: vertical.add,
                    children: const [SizedBox(), SizedBox(), SizedBox()],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (horizontal, vertical);
    }

    testWidgets('the axis the gesture starts on owns its whole length', (
      tester,
    ) async {
      final events = StreamController<PlatformEvent>.broadcast();
      addTearDown(events.close);
      final (horizontal, vertical) = await pumpBothRows(tester, events);

      _swipeBegin(events);
      // The tile row claims the gesture on a horizontal move...
      _swipeUpdate(events, dx: 400, dy: 0, time: 0);
      // ...and a vertical move later in the same gesture must not scroll the
      // workspace row too.
      _swipeUpdate(events, dx: 0, dy: 400, time: 16);
      _swipeEnd(events, time: 32);
      await tester.pumpAndSettle();

      expect(horizontal, [1]);
      expect(vertical, isEmpty);
    });

    testWidgets('the axis lock is symmetric', (tester) async {
      final events = StreamController<PlatformEvent>.broadcast();
      addTearDown(events.close);
      final (horizontal, vertical) = await pumpBothRows(tester, events);

      _swipeBegin(events);
      _swipeUpdate(events, dx: 0, dy: 400, time: 0);
      _swipeUpdate(events, dx: 400, dy: 0, time: 16);
      _swipeEnd(events, time: 32);
      await tester.pumpAndSettle();

      expect(vertical, [1]);
      expect(horizontal, isEmpty);
    });
  });
}

class _StatefulPage extends StatefulWidget {
  const _StatefulPage({required this.id, super.key});
  final String id;

  @override
  State<_StatefulPage> createState() => _StatefulPageState();
}

class _StatefulPageState extends State<_StatefulPage> {
  @override
  Widget build(BuildContext context) => Text(widget.id);
}
