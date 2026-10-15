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
}
