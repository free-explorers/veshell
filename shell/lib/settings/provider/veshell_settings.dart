import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/veshell_settings.serializable.dart';
import 'package:shell/settings/provider/merged_settings_json.dart';

part 'veshell_settings.g.dart';

@Riverpod(keepAlive: true)
class VeshellSettingsState extends _$VeshellSettingsState {
  @override
  VeshellSettings build() {
    final mergedSettingsJson = ref.watch(mergedSettingsJsonProvider);
    return VeshellSettings.fromJson(mergedSettingsJson);
  }
}
