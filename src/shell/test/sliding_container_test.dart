import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/widget/sliding_container.dart';

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
  return tester.getSize(find.byType(PageView));
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
  return tester.widget<PageView>(find.byType(PageView)).controller?.page;
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
