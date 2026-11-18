import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/key_press/model/key_press_history.dart';
import 'package:shell/key_press/provider/key_press_recorder.dart';
import 'package:shell/settings/provider/state/show_key_presses_setting.dart';
import 'package:shell/status_bar/provider/status_bar_settings.dart';
import 'package:shell/status_bar/widget/status_top_panel.dart';
import 'package:shell/theme/provider/theme.dart';

/// Shows the keys pressed in a corner or at an edge of the monitor
/// (`keyboard.keyPressPosition`, bottom right by default), for screencasts and
/// presentations, while `keyboard.showKeyPresses` is on.
///
/// Mounted on every monitor, so whichever one is recorded shows them. It
/// never takes pointer input or focus.
class KeyPressOverlay extends ConsumerWidget {
  const KeyPressOverlay({super.key});

  /// Space left between the panel and the shell's panels or the edge.
  static const gap = 32.0;

  /// Distance from the bottom edge, which no shell panel runs along.
  static const bottomMargin = 72.0;

  /// Distance from the monitor's edges, clear of the screen panel down the
  /// left edge, and of the workspace panel (and the status bar's top panel
  /// when [statusTopPanel]) along the top.
  static EdgeInsets marginFor({required bool statusTopPanel}) =>
      EdgeInsets.fromLTRB(
        panelSize + gap,
        panelSize + (statusTopPanel ? StatusTopPanel.height : 0) + gap,
        gap,
        bottomMargin,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showKeyPressesSettingProvider)) {
      return const SizedBox.shrink();
    }
    final history = ref.watch(keyPressRecorderProvider);
    final position = ref.watch(keyPressPositionSettingProvider);
    final statusTopPanel = ref.watch(
      statusBarSettingsProvider.select((settings) => settings.showsTopPanel),
    );
    return IgnorePointer(
      child: ExcludeFocus(
        child: Align(
          alignment: position.alignment,
          child: Padding(
            padding: marginFor(statusTopPanel: statusTopPanel),
            child: AnimatedOpacity(
              opacity: history.visible ? 1 : 0,
              duration: Duration(milliseconds: history.visible ? 90 : 350),
              curve: Curves.easeOut,
              child: history.shown == null
                  ? const SizedBox.shrink()
                  : KeyPressPanel(history: history),
            ),
          ),
        ),
      ),
    );
  }
}

/// The panel of the visualization: the latest chord, or the modifiers held
/// for the next one, with the keys held right now highlighted.
class KeyPressPanel extends StatelessWidget {
  const KeyPressPanel({required this.history, super.key});

  final KeyPressHistory history;

  @override
  Widget build(BuildContext context) {
    final shown = history.shown;
    if (shown == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final style = _textStyle(context);
    final muted = style.copyWith(color: style.color!.withValues(alpha: 0.6));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 24),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                for (final (index, key) in shown.keys.indexed) ...[
                  if (index > 0) Text('+', style: muted),
                  Keycap(label: key, pressed: history.pressed.contains(key)),
                ],
                if (shown.count > 1) Text('×${shown.count}', style: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One key of the chord; a [pressed] key is lit and sits lower.
class Keycap extends StatelessWidget {
  const Keycap({required this.label, required this.pressed, super.key});

  final String label;
  final bool pressed;

  static const _travel = 2.0;
  static const _depth = 3.0;
  static const _duration = Duration(milliseconds: 70);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    // The darker base peeking out below the cap gives it its depth; a
    // pressed cap sinks into it.
    return AnimatedContainer(
      duration: _duration,
      margin: EdgeInsets.only(top: pressed ? _travel : 0),
      padding: EdgeInsets.only(bottom: pressed ? _depth - _travel : _depth),
      decoration: BoxDecoration(
        color: pressed ? colorScheme.primary : colorScheme.outline,
        borderRadius: radius,
      ),
      child: AnimatedContainer(
        duration: _duration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: pressed
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: radius,
          border: Border.all(
            color: pressed ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: _duration,
          style: _textStyle(context).copyWith(
            color: pressed
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

TextStyle _textStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.headlineSmall!.copyWith(
    color: theme.colorScheme.onSurface,
    fontWeight: FontWeight.w600,
  );
}
