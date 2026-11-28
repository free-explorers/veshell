import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/helm/control_panel/audio/widget/device_slider.dart';
import 'package:shell/overview/helm/control_panel/display/provider/display_brightness.dart';
import 'package:shell/overview/helm/control_panel/display/provider/night_light_state.dart';
import 'package:shell/settings/model/night_light_choices.dart';
import 'package:shell/settings/provider/state/night_light_setting.dart';
import 'package:shell/shared/widget/shell_icon.dart';

/// The Helm's Display card: the backlight slider and the Night Light toggle.
///
/// Each row shows only when the compositor can drive it (a backlight, an
/// output with a colour lookup table); without either there is no card.
Widget? displaySection(WidgetRef ref) {
  final hasBrightness = ref.watch(displayBrightnessProvider) != null;
  final hasNightLight = ref.watch(nightLightStateProvider)?.supported ?? false;
  if (!hasBrightness && !hasNightLight) return null;
  return const DisplayControl();
}

class DisplayControl extends ConsumerWidget {
  const DisplayControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(displayBrightnessProvider);
    final nightLight = ref.watch(nightLightStateProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ShellIcon(
                  MdiIcons.monitor,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    context.l10n.display,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          if (brightness != null) _BrightnessRow(brightness: brightness),
          if (nightLight != null && nightLight.supported)
            _NightLightRow(active: nightLight.active),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _BrightnessRow extends ConsumerWidget {
  const _BrightnessRow({required this.brightness});

  final double brightness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Padding(
        padding: EdgeInsets.all(8),
        child: ShellIcon(MdiIcons.brightness6),
      ),
      title: DeviceSlider(
        label: context.l10n.brightness,
        value: brightness,
        onChanged: (value) =>
            ref.read(displayBrightnessProvider.notifier).set(value),
      ),
    );
  }
}

class _NightLightRow extends ConsumerWidget {
  const _NightLightRow({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(nightLightScheduleProvider);
    final subtitle = nightLightSubtitle(
      context.l10n,
      schedule: schedule,
      active: active,
    );
    void toggle(bool enabled) =>
        ref.read(nightLightStateProvider.notifier).setEnabled(enabled: enabled);
    return ListTile(
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: ShellIcon(
          active ? MdiIcons.weatherNight : MdiIcons.weatherSunny,
        ),
      ),
      title: Text(context.l10n.nightLight),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Switch(value: active, onChanged: toggle),
      onTap: () => toggle(!active),
    );
  }
}

/// When Night Light changes next, for a schedule: on, it lasts until the
/// window ends (the schedule takes over a toggle made before the window);
/// off, it waits for the window to start (a toggle made during the window
/// lasts until it ends, and the next one starts at its usual time). Without a
/// schedule only the toggle changes it, so there is nothing to say.
String? nightLightSubtitle(
  AppLocalizations l10n, {
  required NightLightSchedule schedule,
  required bool active,
}) {
  if (!schedule.scheduled) return null;
  if (schedule.from == schedule.to) return null;
  final time = active ? schedule.to : schedule.from;
  final label = formatNightLightTime(l10n.localeName, time.hour, time.minute);
  return active
      ? l10n.nightLightOnUntil(label)
      : l10n.nightLightOffUntil(label);
}
