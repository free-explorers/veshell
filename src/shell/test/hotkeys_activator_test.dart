import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/settings/provider/state/hotkeys_setting.dart';
import 'package:shell/shortcut_manager/model/media_intents.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';

void main() {
  LogicalKeySet single(LogicalKeyboardKey key) =>
      LogicalKeySet.fromSet(<LogicalKeyboardKey>{key});

  final playPauseFamily = <LogicalKeyboardKey>[
    LogicalKeyboardKey.mediaPlayPause,
    LogicalKeyboardKey.mediaPlay,
    LogicalKeyboardKey.mediaPause,
  ];

  test('a play/pause binding accepts the whole play/pause key family', () {
    final container = ProviderContainer(
      overrides: [
        hotkeysSettingProvider.overrideWithValue({
          HotkeysAction.mediaPlayPause.actionId: single(
            LogicalKeyboardKey.mediaPlay,
          ),
        }),
      ],
    );
    addTearDown(container.dispose);

    final activators = container.read(hotkeysActivatorProvider);

    for (final key in playPauseFamily) {
      expect(
        activators[single(key)],
        isA<MediaPlayPauseIntent>(),
        reason: '$key should trigger play/pause',
      );
    }
  });

  test('a custom play/pause binding is not expanded to the media keys', () {
    final custom = LogicalKeySet.fromSet(<LogicalKeyboardKey>{
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyP,
    });

    final container = ProviderContainer(
      overrides: [
        hotkeysSettingProvider.overrideWithValue({
          HotkeysAction.mediaPlayPause.actionId: custom,
        }),
      ],
    );
    addTearDown(container.dispose);

    final activators = container.read(hotkeysActivatorProvider);

    expect(activators[custom], isA<MediaPlayPauseIntent>());
    for (final key in playPauseFamily) {
      expect(activators.containsKey(single(key)), isFalse);
    }
  });
}
