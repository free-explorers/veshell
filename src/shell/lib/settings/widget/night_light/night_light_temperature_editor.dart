import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/state/night_light_setting.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

/// The stored Night Light temperature, clamped to the supported range, or the
/// default when unset or malformed.
int nightLightTemperature(WidgetRef ref, String path) {
  final value = ref.watch(jsonValueByPathProvider(path));
  if (value is! num || !value.isFinite) return nightLightTemperatureFallback;
  return value.round().clamp(
    nightLightMinTemperature,
    nightLightMaxTemperature,
  );
}

/// Trailing summary of the Night Light temperature: `2700 K`.
class NightLightTemperatureValue extends ConsumerWidget {
  const NightLightTemperatureValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text(context.l10n.kelvinValue(nightLightTemperature(ref, path)));
}

/// Picks the Night Light temperature on a slider, warm on the left. The value
/// is saved when the drag ends: every save rewrites the settings file and the
/// compositor reloads it, which a drag must not do at every step.
class NightLightTemperatureEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<int> {
  const NightLightTemperatureEditor({
    required this.path,
    required this.property,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<int> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = nightLightTemperature(ref, path);
    final dragged = useState<double?>(null);
    // The value dropped and the stored value at the time: shown until the
    // saved value comes back from the settings file, so the handle does not
    // jump back meanwhile.
    final dropped = useState<(double, int)?>(null);
    final droppedValue = dropped.value;
    final value =
        dragged.value ??
        (droppedValue != null && droppedValue.$2 == stored
            ? droppedValue.$1
            : stored.toDouble());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: value,
              min: nightLightMinTemperature.toDouble(),
              max: nightLightMaxTemperature.toDouble(),
              divisions:
                  (nightLightMaxTemperature - nightLightMinTemperature) ~/ 100,
              label: context.l10n.kelvinValue(value.round()),
              onChanged: (value) => dragged.value = value,
              onChangeEnd: (value) {
                dragged.value = null;
                dropped.value = (value, stored);
                ref
                    .read(settingsPropertiesProvider.notifier)
                    .updateProperty(
                      path,
                      property.serializeValue(value.round()),
                    );
              },
            ),
          ),
          const SizedBox(width: 16),
          Text(context.l10n.kelvinValue(value.round())),
        ],
      ),
    );
  }
}
