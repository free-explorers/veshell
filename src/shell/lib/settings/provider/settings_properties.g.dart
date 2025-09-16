// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_properties.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SettingsProperties)
const settingsPropertiesProvider = SettingsPropertiesProvider._();

final class SettingsPropertiesProvider
    extends $NotifierProvider<SettingsProperties, Map<String, SettingGroup>> {
  const SettingsPropertiesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsPropertiesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsPropertiesHash();

  @$internal
  @override
  SettingsProperties create() => SettingsProperties();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, SettingGroup> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, SettingGroup>>(value),
    );
  }
}

String _$settingsPropertiesHash() =>
    r'6ab4b12fe744c7a4a1448bcedbd8a2a0b4837c04';

abstract class _$SettingsProperties
    extends $Notifier<Map<String, SettingGroup>> {
  Map<String, SettingGroup> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<Map<String, SettingGroup>, Map<String, SettingGroup>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, SettingGroup>, Map<String, SettingGroup>>,
              Map<String, SettingGroup>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
