import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/sliding_container.dart';

/// The container's pages: the scrollable a `PageView` would build.
final _pages = find.descendant(
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
              direction: Axis.horizontal,
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
              direction: Axis.horizontal,
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
