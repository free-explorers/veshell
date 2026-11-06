import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/dev_tools/probe/probe_service.dart';

void main() {
  late ProviderContainer container;
  late VeshellProbe probe;

  setUp(() {
    container = ProviderContainer();
    probe = VeshellProbe(container);
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = const Size(400, 300)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  Map<String, Object?> only(Map<String, Object?> found) {
    expect(found['count'], 1, reason: '$found');
    return (found['matches']! as List).single as Map<String, Object?>;
  }

  Rect rectOf(Object? json) {
    final rect = json! as Map<String, Object?>;
    return Rect.fromLTWH(
      rect['left']! as double,
      rect['top']! as double,
      rect['width']! as double,
      rect['height']! as double,
    );
  }

  group('find', () {
    testWidgets('by key, type or text, with the global rect', (tester) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 30, top: 40),
            child: SizedBox(
              key: ValueKey('box'),
              width: 100,
              height: 50,
              child: Text('Hello'),
            ),
          ),
        ),
      );

      final box = only(probe.find(const ProbeQuery(key: 'box')));
      expect(box['type'], 'SizedBox');
      expect(rectOf(box['rect']), const Rect.fromLTWH(30, 40, 100, 50));
      expect(box['visible'], isTrue);
      expect(box['opacity'], 1);

      expect(only(probe.find(const ProbeQuery(text: 'Hell')))['text'], 'Hello');
      expect(
        probe.find(const ProbeQuery(type: 'SizedBox', key: 'box'))['count'],
        1,
      );
      expect(probe.find(const ProbeQuery(key: 'nothing'))['count'], 0);
    });

    testWidgets('reports what ancestor clips leave in view', (tester) async {
      await pump(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            height: 100,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: 300,
                child: Row(
                  children: [
                    SizedBox(key: ValueKey('in'), width: 100, height: 100),
                    SizedBox(key: ValueKey('out'), width: 100, height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final shown = only(probe.find(const ProbeQuery(key: 'in')));
      expect(rectOf(shown['visibleRect']), const Rect.fromLTWH(0, 0, 100, 100));
      final clipped = only(probe.find(const ProbeQuery(key: 'out')));
      expect(rectOf(clipped['rect']), const Rect.fromLTWH(100, 0, 100, 100));
      expect(clipped['visibleRect'], isNull);
      expect(clipped['visible'], isFalse);
    });

    testWidgets('multiplies the ancestors opacities', (tester) async {
      await pump(
        tester,
        const Opacity(
          opacity: 0.5,
          child: Opacity(
            opacity: 0.5,
            child: SizedBox(key: ValueKey('faded'), width: 10, height: 10),
          ),
        ),
      );
      expect(only(probe.find(const ProbeQuery(key: 'faded')))['opacity'], 0.25);
    });

    testWidgets('reports a box a transform collapses as nowhere', (
      tester,
    ) async {
      await pump(
        tester,
        Transform(
          transform: Matrix4.diagonal3Values(double.nan, 1, 1),
          child: const SizedBox(key: ValueKey('gone'), width: 10, height: 10),
        ),
      );
      final gone = only(probe.find(const ProbeQuery(key: 'gone')));
      expect(gone['degenerate'], isTrue);
      expect(gone['rect'], isNull);
      expect(gone['visible'], isFalse);
    });

    testWidgets('tells a page skipped by its sliver from a painted one', (
      tester,
    ) async {
      // Page 1 is built (neighbours kept) and translated over page 0's slot,
      // but its own slot is out of view: the sliver does not paint it.
      await pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            height: 100,
            child: PageView(
              allowImplicitScrolling: true,
              children: const [
                SizedBox(key: ValueKey('page0')),
                FractionalTranslation(
                  translation: Offset(-1, 0),
                  child: SizedBox(key: ValueKey('page1')),
                ),
              ],
            ),
          ),
        ),
      );

      final shown = only(probe.find(const ProbeQuery(key: 'page0')));
      expect(shown['painted'], isTrue);
      expect(shown['visible'], isTrue);
      final skipped = only(probe.find(const ProbeQuery(key: 'page1')));
      expect(rectOf(skipped['rect']), const Rect.fromLTWH(0, 0, 100, 100));
      expect(skipped['painted'], isFalse);
      expect(skipped['visible'], isFalse);
    });

    testWidgets('an offstage box is not painted', (tester) async {
      await pump(
        tester,
        const Offstage(
          child: SizedBox(key: ValueKey('hidden'), width: 10, height: 10),
        ),
      );
      final hidden = only(probe.find(const ProbeQuery(key: 'hidden')));
      expect(hidden['painted'], isFalse);
      expect(hidden['visible'], isFalse);
    });

    test('needs something to look for', () {
      expect(
        () => ProbeQuery.fromParams(const {}),
        throwsA(isA<ProbeException>()),
      );
    });
  });

  group('act', () {
    testWidgets('taps a found widget', (tester) async {
      var taps = 0;
      await pump(
        tester,
        Center(
          child: InkWell(
            key: const ValueKey('button'),
            onTap: () => taps++,
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      );

      final result = await probe.act(const {'action': 'tap', 'key': 'button'});
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect((result['tapped']! as Map)['x'], 200);
    });

    testWidgets('presses a key through the focus system', (tester) async {
      final pressed = <LogicalKeyboardKey>[];
      await pump(
        tester,
        Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              pressed.add(event.logicalKey);
            }
            return KeyEventResult.handled;
          },
          child: const SizedBox.expand(),
        ),
      );
      await tester.pump();

      await probe.act(const {'action': 'key', 'key': 'Arrow Down'});
      await probe.act(const {'action': 'key', 'key': 'escape'});
      expect(pressed, [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.escape,
      ]);
      expect(HardwareKeyboard.instance.logicalKeysPressed, isEmpty);
    });

    testWidgets('types into the focused field, and Enter submits it', (
      tester,
    ) async {
      final submitted = <String>[];
      final changes = <String>[];
      await pump(
        tester,
        TextField(
          autofocus: true,
          onChanged: changes.add,
          onSubmitted: submitted.add,
        ),
      );
      await tester.pump();

      await probe.act(const {'action': 'type', 'text': 'fire'});
      await probe.act(const {'action': 'type', 'text': 'fox'});
      await tester.pump();
      expect(changes.last, 'firefox');

      await probe.act(const {'action': 'key', 'key': 'Enter'});
      expect(submitted, ['firefox']);

      await probe.act(const {'action': 'type', 'text': 'x', 'clear': 'true'});
      expect(changes.last, 'x');
    });

    test('rejects an unknown action or key', () async {
      await expectLater(
        probe.act(const {'action': 'dance'}),
        throwsA(isA<ProbeException>()),
      );
      await expectLater(
        probe.act(const {'action': 'key', 'key': 'NoSuchKey'}),
        throwsA(isA<ProbeException>()),
      );
    });
  });

  testWidgets('captures what a view painted, cropped and scaled', (
    tester,
  ) async {
    await pump(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 300,
          child: ColoredBox(color: Color(0xFFFF0000)),
        ),
      ),
    );

    final result = (await tester.runAsync(
      () => probe.capture(const {
        'left': '150',
        'top': '0',
        'width': '100',
        'height': '100',
        'pixelRatio': '0.5',
      }),
    ))!;
    expect(result['pixelWidth'], 50);
    expect(result['pixelHeight'], 50);

    final image = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        base64Decode(result['png']! as String),
      );
      return (await codec.getNextFrame()).image;
    }))!;
    final pixels = (await tester.runAsync(image.toByteData))!;
    int redAt(int x, int y) => pixels.getUint8((y * image.width + x) * 4);
    // The left half of the crop is the red box, the right half is not.
    expect(redAt(10, 25), 255);
    expect(redAt(40, 25), lessThan(255));
  });

  test('state rejects an unknown store', () {
    expect(() => probe.state('nope'), throwsA(isA<ProbeException>()));
  });
}
