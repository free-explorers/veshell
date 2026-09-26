import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/monitor/provider/monitor_configuration_flex.dart';

ScreenConfiguration _screen(String screenId, int flex) =>
    ScreenConfiguration(flex: flex, screenId: screenId);

IList<ScreenConfiguration> _layout(List<ScreenConfiguration> screens) =>
    screens.lock;

int _total(IList<ScreenConfiguration> layout) =>
    layout.fold(0, (sum, screen) => sum + screen.flex);

void main() {
  group('addScreenToLayout', () {
    test('fills an empty layout with one full-flex primary screen', () {
      final layout = addScreenToLayout(
        IList<ScreenConfiguration>(),
        'screen-a',
        primaryForMonitor: 'DP-1',
      );

      expect(layout, hasLength(1));
      expect(layout.single.screenId, 'screen-a');
      expect(layout.single.flex, monitorLayoutTotalFlex);
      expect(layout.single.primaryForMonitor, 'DP-1');
    });

    test('stays equal and sums to the total for 1->2->3->4', () {
      var layout = _layout([_screen('a', monitorLayoutTotalFlex)]);
      var expectedLength = 1;

      for (final screenId in ['b', 'c', 'd']) {
        layout = addScreenToLayout(layout, screenId);
        expectedLength++;

        expect(layout, hasLength(expectedLength));
        expect(_total(layout), monitorLayoutTotalFlex);

        // Starting from an equal split, the screens stay equal (up to the
        // single flex unit the integer split cannot divide evenly).
        final share = monitorLayoutTotalFlex ~/ layout.length;
        for (final screen in layout) {
          expect(screen.flex, closeTo(share, 1));
        }
      }
    });

    test('preserves existing proportions when a screen is added', () {
      final layout = addScreenToLayout(
        _layout([_screen('a', 70), _screen('b', 30)]),
        'c',
      );

      expect(layout.map((screen) => screen.screenId), ['a', 'b', 'c']);
      expect(_total(layout), monitorLayoutTotalFlex);
      expect(layout[0].flex / layout[1].flex, closeTo(70 / 30, 0.05));
    });
  });

  group('removeLastScreenFromLayout', () {
    test('lets a single remaining screen fill the monitor', () {
      final layout = removeLastScreenFromLayout(
        _layout([_screen('a', 50), _screen('b', 50)]),
      );

      expect(layout, hasLength(1));
      expect(layout.single.screenId, 'a');
      expect(layout.single.flex, monitorLayoutTotalFlex);
    });

    test('rescales the remaining screens and keeps the total', () {
      var layout = _layout([_screen('a', monitorLayoutTotalFlex)]);
      for (final screenId in ['b', 'c', 'd']) {
        layout = addScreenToLayout(layout, screenId);
      }

      layout = removeLastScreenFromLayout(layout);

      expect(layout, hasLength(3));
      expect(_total(layout), monitorLayoutTotalFlex);
    });

    test('removing the only screen yields an empty layout', () {
      expect(removeLastScreenFromLayout(_layout([_screen('a', 100)])), isEmpty);
    });

    test('adding then removing restores the original proportions', () {
      final layout = _layout([_screen('a', 60), _screen('b', 40)]);

      final restored = removeLastScreenFromLayout(
        addScreenToLayout(layout, 'c'),
      );

      expect(
        restored.map((screen) => screen.flex).toList(),
        layout.map((screen) => screen.flex).toList(),
      );
      expect(
        restored.map((screen) => screen.screenId).toList(),
        layout.map((screen) => screen.screenId).toList(),
      );
    });
  });
}
