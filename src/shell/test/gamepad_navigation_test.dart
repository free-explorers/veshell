import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/gamepad/model/gamepad_button.dart';
import 'package:shell/gamepad/model/gamepad_chord_resolver.dart';
import 'package:shell/gamepad/provider/gamepad_bindings.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';

const _up = NavigateIntent(NavigationDirection.up);
const _left = NavigateIntent(NavigationDirection.left);
const _moveLeft = MoveIntent(NavigationDirection.left);
const _cycleBackward = CycleIntent(forward: false);

GamepadChord _chord(String text) => GamepadChord.tryParse(text)!;

void main() {
  group('GamepadChord', () {
    test('parses buttons joined by +, in any order', () {
      expect(
        _chord('leftShoulder+dpadLeft').key,
        _chord('dpadLeft+leftShoulder').key,
      );
      expect(_chord('south').buttons, {GamepadButton.south});
    });

    test('rejects an unknown or empty chord', () {
      expect(GamepadChord.tryParse('south+nope'), isNull);
      expect(GamepadChord.tryParse(''), isNull);
    });
  });

  group('GamepadChordResolver', () {
    late List<Intent> invoked;
    GamepadChordResolver resolver(List<(String, Intent)> bindings) {
      invoked = [];
      return GamepadChordResolver(
        bindings: [
          for (final (text, intent) in bindings) (_chord(text), intent),
        ],
        invoke: invoked.add,
      );
    }

    test('fires a single-button binding on press', () {
      final r = resolver([('south', const ActivateIntent())]);
      r.handle(GamepadButton.south, pressed: true);
      expect(invoked, [isA<ActivateIntent>()]);
      r.handle(GamepadButton.south, pressed: false);
      expect(invoked, hasLength(1));
    });

    test('a chord fires when its last button is pressed', () {
      final r = resolver([
        ('dpadLeft', _left),
        ('leftShoulder+dpadLeft', _moveLeft),
      ]);
      r
        ..handle(GamepadButton.leftShoulder, pressed: true)
        ..handle(GamepadButton.dpadLeft, pressed: true);
      expect(invoked, [_moveLeft]);
    });

    test('a prefix of a longer chord fires on release when used alone', () {
      final r = resolver([
        ('leftShoulder', _cycleBackward),
        ('leftShoulder+dpadLeft', _moveLeft),
      ]);
      r.handle(GamepadButton.leftShoulder, pressed: true);
      expect(invoked, isEmpty);
      r.handle(GamepadButton.leftShoulder, pressed: false);
      expect(invoked, [_cycleBackward]);
    });

    test('a prefix used in a chord does not fire on release', () {
      final r = resolver([
        ('leftShoulder', _cycleBackward),
        ('leftShoulder+dpadLeft', _moveLeft),
      ]);
      r
        ..handle(GamepadButton.leftShoulder, pressed: true)
        ..handle(GamepadButton.dpadLeft, pressed: true)
        ..handle(GamepadButton.dpadLeft, pressed: false)
        ..handle(GamepadButton.leftShoulder, pressed: false);
      expect(invoked, [_moveLeft]);
    });

    test('an unbound set of held buttons fires nothing', () {
      final r = resolver([('south', const ActivateIntent())]);
      r
        ..handle(GamepadButton.east, pressed: true)
        ..handle(GamepadButton.south, pressed: true);
      expect(invoked, isEmpty);
    });

    test('a duplicate press or a release without press is ignored', () {
      final r = resolver([('south', const ActivateIntent())]);
      r
        ..handle(GamepadButton.south, pressed: false)
        ..handle(GamepadButton.south, pressed: true)
        ..handle(GamepadButton.south, pressed: true);
      expect(invoked, hasLength(1));
    });

    test('a held direction repeats after the delay, until released', () {
      fakeAsync((async) {
        final r = resolver([('dpadUp', _up)]);
        r.handle(GamepadButton.dpadUp, pressed: true);
        expect(invoked, hasLength(1));
        async.elapse(const Duration(milliseconds: 399));
        expect(invoked, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(invoked, hasLength(2));
        async.elapse(const Duration(milliseconds: 240));
        expect(invoked, hasLength(4));
        r.handle(GamepadButton.dpadUp, pressed: false);
        async.elapse(const Duration(seconds: 1));
        expect(invoked, hasLength(4));
      });
    });

    test('activation does not repeat', () {
      fakeAsync((async) {
        final r = resolver([('south', const ActivateIntent())]);
        r.handle(GamepadButton.south, pressed: true);
        async.elapse(const Duration(seconds: 2));
        expect(invoked, hasLength(1));
      });
    });

    test('pressing another button stops a repeat', () {
      fakeAsync((async) {
        final r = resolver([('dpadUp', _up)]);
        r.handle(GamepadButton.dpadUp, pressed: true);
        async.elapse(const Duration(milliseconds: 100));
        r.handle(GamepadButton.south, pressed: true);
        async.elapse(const Duration(seconds: 1));
        expect(invoked, hasLength(1));
      });
    });
  });

  group('parseGamepadBindings', () {
    test('maps nested action ids to their intents', () {
      final bindings = parseGamepadBindings({
        'navigation': {
          'up': ['dpadUp', 'leftStickUp'],
          'dismiss': ['east'],
        },
        'overview': {
          'toggle': ['start'],
        },
      });
      expect(bindings, hasLength(4));
      expect(bindings.first.$2, isA<NavigateIntent>());
      expect(
        bindings.map((binding) => binding.$2),
        containsAll([isA<DismissIntent>(), isA<ToggleOverviewIntent>()]),
      );
    });

    test('skips unknown actions and malformed chords', () {
      final bindings = parseGamepadBindings({
        'navigation': {
          'nope': ['south'],
          'up': ['dpadUp', 'typo', 42],
        },
      });
      expect(bindings, hasLength(1));
    });

    test('every shipped default binding parses', () {
      final defaults =
          jsonDecode(
                File(
                  '../../extra/settings/default/settings.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final json = (defaults['gamepad'] as Map)['bindings'];
      var chords = 0;
      void count(Object? node) {
        if (node is Map) {
          node.values.forEach(count);
        } else if (node is List) {
          chords += node.length;
        }
      }

      count(json);
      expect(parseGamepadBindings(json), hasLength(chords));
    });
  });
}
