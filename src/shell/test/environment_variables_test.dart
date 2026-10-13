import 'package:flutter_test/flutter_test.dart';
import 'package:shell/settings/model/environment_variables.dart';

void main() {
  test('environmentVariablesFromJson reads string-to-string entries', () {
    expect(
      environmentVariablesFromJson({
        'QT_QPA_PLATFORM': 'xcb',
        'QT_STYLE_OVERRIDE': 'Adwaita',
      }),
      {'QT_QPA_PLATFORM': 'xcb', 'QT_STYLE_OVERRIDE': 'Adwaita'},
    );
  });

  test('environmentVariablesFromJson tolerates malformed settings values', () {
    expect(environmentVariablesFromJson(null), isEmpty);
    expect(environmentVariablesFromJson('nope'), isEmpty);
    expect(environmentVariablesFromJson(<Object>[]), isEmpty);
    // A hand-edited file can hold non-string entries; they are ignored rather
    // than crashing the editor.
    expect(
      environmentVariablesFromJson({'VALID': 'ok', 'NUMBER': 1, 2: 'two'}),
      {'VALID': 'ok'},
    );
  });

  test('isEnvironmentVariableName follows the portable POSIX name shape', () {
    for (final name in ['PATH', '_private', 'A1', 'QT_QPA_PLATFORM']) {
      expect(isEnvironmentVariableName(name), isTrue, reason: name);
    }
    for (final name in [
      '',
      '1LEADING',
      'has-dash',
      'has space',
      'has=eq',
      'é',
    ]) {
      expect(isEnvironmentVariableName(name), isFalse, reason: name);
    }
  });
}
