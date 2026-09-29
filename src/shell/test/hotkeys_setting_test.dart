import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/state/hotkeys_setting.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/provider/util/setting_definition_by_path.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';

void main() {
  const path = 'keyboard.hotkeys';

  SettingProperty<LogicalKeySet> hotkey(String name) => SettingProperty(
    name: name,
    description: '',
    converter: const LogicalKeySetConverter(),
    key: name,
  );

  test('malformed stored hotkeys are skipped instead of crashing', () {
    final container = ProviderContainer(
      overrides: [
        settingDefinitionByPathProvider(path).overrideWithValue(
          SettingGroup(
            name: 'Hotkeys',
            description: null,
            children: {
              'media.playPause': hotkey('Play/Pause'),
              'media.next': hotkey('Next'),
            },
          ),
        ),
        jsonValueByPathProvider(
          '$path.media.playPause',
        ).overrideWithValue('null'),
        jsonValueByPathProvider(
          '$path.media.next',
        ).overrideWithValue('mediaTrackNext'),
      ],
    );
    addTearDown(container.dispose);

    final hotkeys = container.read(hotkeysSettingProvider);

    expect(
      hotkeys['media.next'],
      LogicalKeySet.fromSet(<LogicalKeyboardKey>{
        LogicalKeyboardKey.mediaTrackNext,
      }),
    );
    expect(hotkeys.containsKey('media.playPause'), isFalse);
  });
}
