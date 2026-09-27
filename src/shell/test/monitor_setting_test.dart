import 'package:flutter_test/flutter_test.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';

/// Desired-geometry payload as Rust's `MonitorConfiguration` parses it.
Map<String, dynamic> _legacyPayload() => {
  'mode': {
    'size': {'width': 1920, 'height': 1080},
    'refreshRate': 60000,
  },
  'fractionnalScale': 1.0,
  'location': {'x': 0, 'y': 0},
};

void main() {
  test('reads a legacy file without transform or mirrorOf', () {
    final setting = MonitorSetting.fromJson(_legacyPayload());

    expect(setting.transform, MonitorTransform.normal);
    expect(setting.mirrorOf, isNull);
  });

  test('round-trips transform and mirrorOf', () {
    final setting = MonitorSetting.fromJson(_legacyPayload()).copyWith(
      transform: MonitorTransform.flipped90,
      mirrorOf: 'DP-2',
    );

    final json = setting.toJson();

    expect(json['transform'], 'flipped90');
    expect(json['mirrorOf'], 'DP-2');
    expect(
      MonitorSetting.fromJson(json).transform,
      MonitorTransform.flipped90,
    );
    expect(MonitorSetting.fromJson(json).mirrorOf, 'DP-2');
  });

  test('isTransposed is true for the quarter-turn transforms only', () {
    expect(MonitorTransform.normal.isTransposed, isFalse);
    expect(MonitorTransform.rotate90.isTransposed, isTrue);
    expect(MonitorTransform.rotate180.isTransposed, isFalse);
    expect(MonitorTransform.rotate270.isTransposed, isTrue);
    expect(MonitorTransform.flipped.isTransposed, isFalse);
    expect(MonitorTransform.flipped90.isTransposed, isTrue);
    expect(MonitorTransform.flipped180.isTransposed, isFalse);
    expect(MonitorTransform.flipped270.isTransposed, isTrue);
  });
}
