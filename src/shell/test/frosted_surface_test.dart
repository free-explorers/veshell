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

  test('frost sigma scales with the region and clamps', () {
    expect(frostSigmaFor(const Size(400, 400)), 8.0);
    expect(frostSigmaFor(const Size(800, 800)), 16.0);
    expect(frostSigmaFor(const Size(2000, 2000)), 28.0);
  });

  testWidgets('ramping the frost keeps the frosted subtree alive', (
    tester,
  ) async {
    // The frost ramps on every overview open, dialog open and game pause. The
    // filters must not be inserted or dropped around the content as it does:
    // that re-inflates everything below the frost — its state, hooks and focus
    // nodes — which is how the overview's search field used to lose the
    // keyboard to the workspace that was remounted behind it.
    var mounts = 0;
    Future<void> pump({
      double blurSigma = 0,
      double saturation = 1,
      Color? tint,
      bool noise = false,
      double noiseOpacity = 0,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FrostedSurface(
            blurSigma: blurSigma,
            saturation: saturation,
            tint: tint,
            noise: noise,
            noiseOpacity: noiseOpacity,
            child: _MountCounter(onMount: () => mounts++),
          ),
        ),
      );
      await tester.pump();
    }

    await pump();
    expect(mounts, 1);

    // Ramping every property a caller animates must reuse the element.
    await pump(blurSigma: 16);
    await pump(blurSigma: 16, saturation: 1.2);
    await pump(blurSigma: 16, saturation: 1.2, tint: Colors.black26);
    await pump(
      blurSigma: 16,
      saturation: 1.2,
      tint: Colors.black26,
      noise: true,
      noiseOpacity: 0.5,
    );
    await pump(
      blurSigma: 16,
      saturation: 1.2,
      tint: Colors.black26,
      noise: true,
      noiseOpacity: 1,
    );
    expect(mounts, 1, reason: 'the frost must not remount what it frosts');

    // And back down: closing ramps the same properties to zero.
    await pump();
    expect(mounts, 1, reason: 'nor when it clears');
  });

  testWidgets('the grain follows noiseOpacity instead of popping', (
    tester,
  ) async {
    Future<void> pump(double noiseOpacity) => tester.pumpWidget(
      MaterialApp(
        home: FrostedSurface(
          blurSigma: 12,
          tint: Colors.black26,
          tintOverContent: true,
          noise: true,
          noiseOpacity: noiseOpacity,
          child: const SizedBox(width: 40, height: 40),
        ),
      ),
    );
    Finder inFrost(Type type) => find.descendant(
      of: find.byType(FrostedSurface),
      matching: find.byType(type),
    );

    // Faded out: no grain at all.
    await pump(0);
    expect(inFrost(CustomPaint), findsNothing);

    // Mid-ramp: the grain rides an `Opacity` layer, so it fades with the wash
    // rather than switching on the instant the blur crosses its floor.
    await pump(0.5);
    expect(inFrost(CustomPaint), findsOneWidget);
    expect(inFrost(Opacity), findsOneWidget);

    // Settled: painted directly, without the extra layer.
    await pump(1);
    expect(inFrost(CustomPaint), findsOneWidget);
    expect(inFrost(Opacity), findsNothing);
  });

  test('the wash lifts a dark scheme and settles a light one', () {
    final dark = ColorScheme.fromSeed(
      seedColor: Colors.red,
      brightness: Brightness.dark,
    );
    final light = ColorScheme.fromSeed(
      seedColor: Colors.red,
      brightness: Brightness.light,
    );

    expect(
      frostedGlassTint(dark).computeLuminance(),
      greaterThan(frostedGlassTint(light).computeLuminance()),
    );
  });
}

/// Counts how often it is mounted, so a test can assert the frost does not
/// re-inflate the subtree it frosts.
class _MountCounter extends StatefulWidget {
  const _MountCounter({required this.onMount});

  final void Function() onMount;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
