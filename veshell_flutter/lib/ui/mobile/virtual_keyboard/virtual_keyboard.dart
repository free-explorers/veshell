import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glissando/glissando.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/ui/mobile/virtual_keyboard/key.dart';
import 'package:zenith/ui/mobile/virtual_keyboard/layouts.dart';

part '../../../generated/ui/mobile/virtual_keyboard/virtual_keyboard.g.dart';

@Riverpod(keepAlive: true)
class KeyboardLayout extends _$KeyboardLayout {
  @override
  KbLayout build() => KbLayouts.en.layout;
}

@Riverpod(keepAlive: true)
int keyboardId(KeyboardIdRef ref) => throw UnimplementedError(); // will be overridden

@riverpod
class KeyboardLayer extends _$KeyboardLayer {
  @override
  KbLayerEnum build(int viewId) => KbLayerEnum.first;
}

@riverpod
class KeyboardCase extends _$KeyboardCase {
  @override
  Case build(int viewId) => Case.lowercase;
}

@Riverpod(keepAlive: true)
class KeyboardKeyWidth extends _$KeyboardKeyWidth {
  @override
  double build(int viewId) => 0.0;
}

class VirtualKeyboard extends ConsumerWidget {
  final VoidCallback onDismiss;
  final void Function(String) onCharacter;
  final void Function(KeyCode) onKeyCode;

  const VirtualKeyboard({
    Key? key,
    required this.onDismiss,
    required this.onCharacter,
    required this.onKeyCode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          double keyWidth = constraints.maxWidth / 10;
          final id = ref.watch(keyboardIdProvider);
          Future.microtask(() => ref.read(keyboardKeyWidthProvider(id).notifier).state = keyWidth);

          // Keyboard presses must not unfocus the active text field.
          return TextFieldTapRegion(
            child: Material(
              color: Color.lerp(Colors.black, Colors.white, 0.9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NotificationListener(
                    child: const KeyboardLayers(),
                    onNotification: (Notification notification) {
                      if (notification is OnCharacterNotification) {
                        onCharacter(notification.character);
                        return true;
                      } else if (notification is OnKeyCodeNotification) {
                        onKeyCode(notification.keyCode);
                        return true;
                      }
                      return false;
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                        padding: EdgeInsets.zero,
                        onPressed: onDismiss,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class KeyboardLayers extends ConsumerWidget {
  const KeyboardLayers({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(keyboardIdProvider);
    final layerIndex = ref.watch(keyboardLayerProvider(id)).index;

    return Glissando(
      child: IndexedStack(
        index: layerIndex,
        children: const [
          KeyboardFirstLayer(),
          KeyboardSecondLayer(),
          KeyboardThirdLayer(),
        ],
      ),
    );
  }
}

class KeyboardFirstLayer extends ConsumerWidget {
  const KeyboardFirstLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(keyboardLayoutProvider);
    final keys = _buildKeys(context, ref, layout.firstLayer);

    return Column(
      children: [
        for (final row in keys)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row,
          ),
      ],
    );
  }

  List<List<Widget>> _buildKeys(BuildContext context, WidgetRef ref, KbLayer layer) {
    final id = ref.watch(keyboardIdProvider);
    double keyWidth = ref.watch(keyboardKeyWidthProvider(id));

    Widget letterKey(String letter) {
      return VirtualKeyboardLetterKey(
        id: id,
        width: keyWidth,
        char: letter,
      );
    }

    Widget slimCharacterKey(String char) {
      return VirtualKeyboardCharacterKey(
        id: id,
        width: keyWidth,
        char: char,
      );
    }

    Widget spaceBarKey(BuildContext context) {
      return Expanded(
        child: VirtualKeyboardKey(
          width: keyWidth,
          onTap: () => OnCharacterNotification(" ").dispatch(context),
          popUpOnPress: false,
          child: const Text(" "),
        ),
      );
    }

    return [
      [for (String char in layer[0]) letterKey(char)],
      [for (String char in layer[1]) letterKey(char)],
      [
        VirtualKeyboardShiftKey(id: id, width: keyWidth),
        for (String char in layer[2]) letterKey(char),
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          repeatOnLongPress: true,
          onTap: () => OnKeyCodeNotification(KeyCode.backspace).dispatch(context),
          child: const Icon(Icons.backspace_outlined),
        ),
      ],
      [
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          child: const Text(
            "?123",
            style: TextStyle(fontSize: 17),
          ),
          onTap: () => ref.read(keyboardLayerProvider(id).notifier).state = KbLayerEnum.second,
        ),
        slimCharacterKey(layer[3][0]),
        VirtualKeyboardKey(
          width: keyWidth,
          popUpOnPress: false,
          child: const Icon(Icons.language),
        ),
        spaceBarKey(context),
        slimCharacterKey(layer[3][1]),
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          onTap: () => OnKeyCodeNotification(KeyCode.enter).dispatch(context),
          child: const Icon(Icons.keyboard_return),
        ),
      ]
    ];
  }
}

class KeyboardSecondLayer extends ConsumerWidget {
  const KeyboardSecondLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(keyboardLayoutProvider);
    final keys = _buildKeys(context, ref, layout.secondLayer);

    return Column(
      children: [
        for (final row in keys)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row,
          ),
      ],
    );
  }

  List<List<Widget>> _buildKeys(BuildContext context, WidgetRef ref, KbLayer layer) {
    final id = ref.watch(keyboardIdProvider);
    double keyWidth = ref.watch(keyboardKeyWidthProvider(id));

    Widget slimCharacterKey(String char) {
      return VirtualKeyboardCharacterKey(
        id: id,
        width: keyWidth,
        char: char,
      );
    }

    Widget spaceBarKey(BuildContext context) {
      return Expanded(
        child: VirtualKeyboardKey(
          width: keyWidth,
          onTap: () => OnCharacterNotification(" ").dispatch(context),
          popUpOnPress: false,
          child: const Text(" "),
        ),
      );
    }

    return [
      [for (String char in layer[0]) slimCharacterKey(char)],
      [for (String char in layer[1]) slimCharacterKey(char)],
      [
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          onTap: () {
            ref.read(keyboardLayerProvider(id).notifier).state = KbLayerEnum.third;
          },
          child: const Text(
            "=\\<",
            style: TextStyle(fontSize: 17),
          ),
        ),
        for (String char in layer[2]) slimCharacterKey(char),
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          repeatOnLongPress: true,
          onTap: () => OnKeyCodeNotification(KeyCode.backspace).dispatch(context),
          child: const Icon(Icons.backspace_outlined),
        ),
      ],
      [
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          child: const Text(
            "ABC",
            style: TextStyle(fontSize: 17),
          ),
          onTap: () {
            ref.read(keyboardLayerProvider(id).notifier).state = KbLayerEnum.first;
          },
        ),
        slimCharacterKey(layer[3][0]),
        slimCharacterKey(layer[3][1]),
        spaceBarKey(context),
        slimCharacterKey(layer[3][2]),
        slimCharacterKey(layer[3][3]),
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          onTap: () => OnKeyCodeNotification(KeyCode.enter).dispatch(context),
          child: const Icon(Icons.keyboard_return),
        ),
      ]
    ];
  }
}

class KeyboardThirdLayer extends ConsumerWidget {
  const KeyboardThirdLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(keyboardLayoutProvider);
    final keys = _buildKeys(context, ref, layout.thirdLayer);

    return Column(
      children: [
        for (final row in keys)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row,
          ),
      ],
    );
  }

  List<List<Widget>> _buildKeys(BuildContext context, WidgetRef ref, KbLayer layer) {
    final id = ref.watch(keyboardIdProvider);
    double keyWidth = ref.watch(keyboardKeyWidthProvider(id));

    Widget slimCharacterKey(String char) {
      return VirtualKeyboardCharacterKey(
        id: id,
        width: keyWidth,
        char: char,
      );
    }

    Widget spaceBarKey(BuildContext context) {
      return Expanded(
        child: VirtualKeyboardKey(
          width: keyWidth,
          onTap: () => OnCharacterNotification(" ").dispatch(context),
          popUpOnPress: false,
          child: const Text(" "),
        ),
      );
    }

    return [
      [for (String char in layer[0]) slimCharacterKey(char)],
      [for (String char in layer[1]) slimCharacterKey(char)],
      [
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          onTap: () {
            ref.read(keyboardLayerProvider(id).notifier).state = KbLayerEnum.second;
          },
          child: const Text(
            "?123",
            style: TextStyle(fontSize: 17),
          ),
        ),
        for (String char in layer[2]) slimCharacterKey(char),
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          repeatOnLongPress: true,
          onTap: () => OnKeyCodeNotification(KeyCode.backspace).dispatch(context),
          child: const Icon(Icons.backspace_outlined),
        ),
      ],
      [
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          child: const Text(
            "ABC",
            style: TextStyle(fontSize: 17),
          ),
          onTap: () {
            ref.read(keyboardLayerProvider(id).notifier).state = KbLayerEnum.first;
          },
        ),
        slimCharacterKey(layer[3][0]),
        slimCharacterKey(layer[3][1]),
        spaceBarKey(context),
        slimCharacterKey(layer[3][2]),
        slimCharacterKey(layer[3][3]),
        VirtualKeyboardKey(
          width: keyWidth * 1.5,
          popUpOnPress: false,
          onTap: () => OnKeyCodeNotification(KeyCode.enter).dispatch(context),
          child: const Icon(Icons.keyboard_return),
        ),
      ]
    ];
  }
}

class OnCharacterNotification extends Notification {
  final String character;

  OnCharacterNotification(this.character);
}

class OnKeyCodeNotification extends Notification {
  final KeyCode keyCode;

  OnKeyCodeNotification(this.keyCode);
}

class VirtualKeyboardLetterKey extends ConsumerWidget {
  final int id;
  final double width;
  final String char;

  const VirtualKeyboardLetterKey({
    Key? key,
    required this.id,
    required this.width,
    required this.char,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VirtualKeyboardKey(
      width: width,
      onTap: () {
        Case letterCase = ref.read(keyboardCaseProvider(id));
        OnCharacterNotification(_applyCasing(char, letterCase)).dispatch(context);

        if (letterCase != Case.capslock) {
          ref.read(keyboardCaseProvider(id).notifier).state = Case.lowercase;
        }
      },
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          Case letterCase = ref.watch(keyboardCaseProvider(id));
          return Text(_applyCasing(char, letterCase));
        },
      ),
    );
  }

  String _applyCasing(String char, Case letterCase) {
    return letterCase != Case.lowercase ? char.toUpperCase() : char;
  }
}

class VirtualKeyboardCharacterKey extends ConsumerWidget {
  final int id;
  final double width;
  final String char;

  const VirtualKeyboardCharacterKey({
    Key? key,
    required this.id,
    required this.width,
    required this.char,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VirtualKeyboardKey(
      width: width,
      onTap: () => OnCharacterNotification(char).dispatch(context),
      child: Text(char),
    );
  }
}

class VirtualKeyboardShiftKey extends ConsumerWidget {
  final int id;
  final double width;

  const VirtualKeyboardShiftKey({
    Key? key,
    required this.id,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VirtualKeyboardKey(
      width: width * 1.5,
      popUpOnPress: false,
      onTap: () {
        final letterCaseNotifier = ref.read(keyboardCaseProvider(id).notifier);
        if (letterCaseNotifier.state == Case.lowercase) {
          letterCaseNotifier.state = Case.uppercase;
        } else {
          letterCaseNotifier.state = Case.lowercase;
        }
      },
      onDoubleTap: () {
        ref.read(keyboardCaseProvider(id).notifier).state = Case.capslock;
      },
      child: Transform.rotate(
        angle: -90 * math.pi / 180,
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final letterCase = ref.watch(keyboardCaseProvider(id));
            return Icon(
              letterCase != Case.lowercase ? Icons.forward : Icons.forward_outlined,
              color: letterCase == Case.capslock ? Colors.blue : null,
            );
          },
        ),
      ),
    );
  }
}
