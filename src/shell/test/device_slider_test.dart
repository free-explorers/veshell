import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/helm/control_panel/audio/widget/device_slider.dart';

void main() {
  testWidgets('paints the device label at every value', (tester) async {
    for (final value in [0.0, 0.5, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: DeviceSlider(
                  value: value,
                  label: 'Built-in Audio Analog Stereo',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('lets the handle reach the track ends', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DeviceSlider(
                value: 1,
                label: 'Built-in Audio Analog Stereo',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final sliderTheme = tester.widget<SliderTheme>(
      find.descendant(
        of: find.byType(DeviceSlider),
        matching: find.byType(SliderTheme),
      ),
    );
    expect(sliderTheme.data.trackShape!.isRounded, isFalse);
  });

  testWidgets('configures the handle height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DeviceSlider(
                value: 0.5,
                label: 'Built-in Audio Analog Stereo',
                handleHeight: 60,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final sliderTheme = tester.widget<SliderTheme>(
      find.descendant(
        of: find.byType(DeviceSlider),
        matching: find.byType(SliderTheme),
      ),
    );
    expect(
      sliderTheme.data.thumbSize!.resolve(<WidgetState>{}),
      const Size(4, 60),
    );
    expect(
      sliderTheme.data.thumbShape!.getPreferredSize(true, false),
      const Size(4, 60),
    );
  });

  testWidgets('paints while the handle is pressed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DeviceSlider(
                value: 0.5,
                label: 'Built-in Audio Analog Stereo',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await gesture.up();
  });

  testWidgets('renders without a label and while disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DeviceSlider(value: 0.5, label: '', onChanged: null),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
