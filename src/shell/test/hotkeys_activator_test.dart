import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/settings/provider/state/hotkeys_setting.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';
import 'package:shell/shortcut_manager/model/layout_intents.dart';
import 'package:shell/shortcut_manager/model/media_intents.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
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
          HotkeysAction.mediaPlayPause.actionId: [
            single(LogicalKeyboardKey.mediaPlay),
          ],
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
          HotkeysAction.mediaPlayPause.actionId: [custom],
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

  test('every binding of an action resolves to the same intent', () {
    final wasd = single(LogicalKeyboardKey.keyW);
    final arrow = single(LogicalKeyboardKey.arrowUp);

    final container = ProviderContainer(
      overrides: [
        hotkeysSettingProvider.overrideWithValue({
          HotkeysAction.navigateUp.actionId: [wasd, arrow],
        }),
      ],
    );
    addTearDown(container.dispose);

    final activators = container.read(hotkeysActivatorProvider);

    for (final activator in [wasd, arrow]) {
      final intent = activators[activator];
      expect(
        intent,
        isA<NavigateIntent>().having(
          (intent) => intent.direction,
          'direction',
          NavigationDirection.up,
        ),
      );
    }
  });

  test('the layout actions change the counts by one', () {
    expect(
      getActionIntent(HotkeysAction.increaseVisibleTiles),
      isA<ChangeVisibleTileCountIntent>().having((i) => i.delta, 'delta', 1),
    );
    expect(
      getActionIntent(HotkeysAction.decreaseVisibleTiles),
      isA<ChangeVisibleTileCountIntent>().having((i) => i.delta, 'delta', -1),
    );
    expect(
      getActionIntent(HotkeysAction.increaseScreens),
      isA<ChangeScreenCountIntent>().having((i) => i.delta, 'delta', 1),
    );
    expect(
      getActionIntent(HotkeysAction.decreaseScreens),
      isA<ChangeScreenCountIntent>().having((i) => i.delta, 'delta', -1),
    );
  });

  test('the shipped layout bindings parse to their keys', () {
    final defaults =
        jsonDecode(
              File(
                '../../extra/settings/default/settings.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final layout =
        ((defaults['keyboard'] as Map)['hotkeys'] as Map)['layout'] as Map;
    const converter = LogicalKeySetListConverter();

    for (final action in [
      HotkeysAction.increaseVisibleTiles,
      HotkeysAction.decreaseVisibleTiles,
      HotkeysAction.increaseScreens,
      HotkeysAction.decreaseScreens,
    ]) {
      final name = action.actionId.split('.').last;
      final bindings = converter.fromJson(layout[name]);
      expect(bindings, hasLength(2), reason: name);
    }
    expect(converter.fromJson(layout['increaseVisibleTiles']).first.keys, {
      LogicalKeyboardKey.superKey,
      LogicalKeyboardKey.equal,
    });
  });
}
