import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/pulseaudio/provider/default_sink.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_sink_by_name.dart';
import 'package:shell/shortcut_manager/model/screen_shortcuts.dart';
import 'package:shell/shortcut_manager/model/system_intents.dart';
import 'package:shell/shortcut_manager/provider/hotkeys_activator.dart';

class VeshellShortcutManager extends HookConsumerWidget {
  const VeshellShortcutManager({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotkeysActivator = ref.watch(hotkeysActivatorProvider);
    print(hotkeysActivator);
    final manager = useMemoized(
      () => _ShortcutManager(shortcuts: hotkeysActivator),
      [hotkeysActivator],
    );
    return Shortcuts.manager(
      manager: manager,
      child: Actions(
        actions: {
          IncreaseVolume: CallbackAction<IncreaseVolume>(
            onInvoke: (IncreaseVolume intent) {
              final defaultSink = ref.read(defaultPulseSinkProvider);
              if (defaultSink == null) return;
              final sink = ref.read(
                pulseSinkByNameProvider(defaultSink.name),
              );
              if (sink == null) return;

              ref
                  .read(pulseClientProvider)
                  .requireValue
                  .setSinkVolume(defaultSink.name, min(sink.volume + 0.05, 1));
              return null;
            },
          ),
          DecreaseVolume: CallbackAction<DecreaseVolume>(
            onInvoke: (DecreaseVolume intent) {
              final defaultSink = ref.read(defaultPulseSinkProvider);
              if (defaultSink == null) return;
              final sink = ref.read(
                pulseSinkByNameProvider(defaultSink.name),
              );
              if (sink == null) return;
              ref.read(pulseClientProvider).requireValue.setSinkVolume(
                    defaultSink.name,
                    max(sink.volume - 0.05, 0),
                  );

              return null;
            },
          ),
          ToggleMute: CallbackAction<ToggleMute>(
            onInvoke: (ToggleMute intent) {
              final defaultSink = ref.read(defaultPulseSinkProvider);
              if (defaultSink == null) return;
              final sink = ref.read(
                pulseSinkByNameProvider(defaultSink.name),
              );
              if (sink == null) return;
              ref.read(pulseClientProvider).requireValue.setSinkMute(
                    defaultSink.name,
                    !sink.mute,
                  );
              return;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _ShortcutManager extends ShortcutManager {
  _ShortcutManager({super.shortcuts});
  bool _isOverviewKeySolePressed = false;
  ToggleOverviewIntent overviewIntent = const ToggleOverviewIntent();
  final LogicalKeyboardKey overviewKey = LogicalKeyboardKey.superKey;
  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    print(event);
    print('is overview ${event.logicalKey == overviewKey}');
    if (event is KeyUpEvent &&
        event.logicalKey == overviewKey &&
        _isOverviewKeySolePressed) {
      print('inside overview');

      _isOverviewKeySolePressed = false;
      final primaryContext = primaryFocus?.context;
      if (primaryContext != null) {
        final action = Actions.maybeFind<Intent>(
          primaryContext,
          intent: overviewIntent,
        );
        if (action != null) {
          final (bool enabled, Object? invokeResult) =
              Actions.of(primaryContext).invokeActionIfEnabled(
            action,
            overviewIntent,
            primaryContext,
          );
          if (enabled) {
            return action.toKeyEventResult(overviewIntent, invokeResult);
          }
        }
      }
    }

    _isOverviewKeySolePressed =
        event is KeyDownEvent && event.logicalKey == overviewKey;

    print('_isOverviewKeySolePressed $_isOverviewKeySolePressed');

    return super.handleKeypress(context, event);
  }
}
