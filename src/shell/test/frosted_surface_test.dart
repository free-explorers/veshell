import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/frosted_surface.dart';

void main() {
  testWidgets('renders its child under the full frosted stack', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 100,
            child: FrostedSurface(
              blurSigma: 8,
              saturation: 1.3,
              tint: Colors.black26,
              tintOverContent: true,
              noise: true,
              child: Text('content'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The blur, saturation, veil, frame and grain must all build and lay out
    // without an exception, with the child still on top.
    expect(find.text('content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tint behind content leaves it untouched', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: FrostedSurface(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              tint: Colors.black26,
              child: SizedBox(width: 120, height: 60),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('absorbPointers swallows taps the content does not take', (
    tester,
  ) async {
    var behind = 0;
    Widget build({required bool absorb}) => MaterialApp(
      home: Stack(
        children: [
          // A full-bleed target painted behind the frost.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => behind++,
            child: const SizedBox.expand(),
          ),
          FrostedSurface(
            tint: Colors.black26,
            absorbPointers: absorb,
            child: const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(build(absorb: true));
    await tester.tapAt(const Offset(300, 300));
    expect(behind, 0, reason: 'the backdrop absorbs the click');

    behind = 0;
    await tester.pumpWidget(build(absorb: false));
    await tester.tapAt(const Offset(300, 300));
    expect(behind, 1, reason: 'without absorption the click falls through');
  });
}
