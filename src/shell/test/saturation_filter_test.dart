import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/saturation_filter.dart';

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox.square(dimension: 10);
}

void main() {
  Widget build(double saturation) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SaturationFilter(saturation: saturation, child: const _Probe()),
    ),
  );

  Iterable<ColorFilterLayer> colorFilterLayers(WidgetTester tester) {
    final render = tester.renderObject<RenderSaturationFilter>(
      find.byType(SaturationFilter),
    );
    return [?render.debugLayer].whereType<ColorFilterLayer>();
  }

  testWidgets('pushes a color filter only while desaturated', (tester) async {
    await tester.pumpWidget(build(1));
    expect(colorFilterLayers(tester), isEmpty);
    final state = tester.state(find.byType(_Probe));

    await tester.pumpWidget(build(0));
    expect(colorFilterLayers(tester), hasLength(1));
    // Toggling the filter keeps the same child state.
    expect(tester.state(find.byType(_Probe)), same(state));

    await tester.pumpWidget(build(1));
    expect(colorFilterLayers(tester), isEmpty);
    expect(tester.state(find.byType(_Probe)), same(state));
  });

  test('saturation matrix is identity at 1 and luminance at 0', () {
    expect(saturationMatrix(1), <double>[
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
    final gray = saturationMatrix(0);
    expect(gray.sublist(0, 3), gray.sublist(5, 8));
    expect(gray.sublist(0, 3), gray.sublist(10, 13));
    expect(gray[0] + gray[1] + gray[2], closeTo(1, 1e-9));
  });

  test('brightness scales the color channels but not alpha', () {
    final dimmed = saturationMatrix(1, brightness: 0.5);
    expect(dimmed[0], 0.5);
    expect(dimmed[6], 0.5);
    expect(dimmed[12], 0.5);
    expect(dimmed[18], 1);
  });

  testWidgets('dimming alone also pushes a color filter', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SaturationFilter(
          saturation: 1,
          brightness: 0.5,
          child: SizedBox.square(dimension: 10),
        ),
      ),
    );
    final render = tester.renderObject<RenderSaturationFilter>(
      find.byType(SaturationFilter),
    );
    expect(render.debugLayer, isA<ColorFilterLayer>());
  });
}
