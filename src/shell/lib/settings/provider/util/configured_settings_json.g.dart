// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'configured_settings_json.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ConfiguredSettingsJson)
const configuredSettingsJsonProvider = ConfiguredSettingsJsonProvider._();

final class ConfiguredSettingsJsonProvider
    extends $NotifierProvider<ConfiguredSettingsJson, Map<String, dynamic>> {
  const ConfiguredSettingsJsonProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'configuredSettingsJsonProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$configuredSettingsJsonHash();

  @$internal
  @override
  ConfiguredSettingsJson create() => ConfiguredSettingsJson();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, dynamic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, dynamic>>(value),
    );
  }
}

String _$configuredSettingsJsonHash() =>
    r'5468fdd697d042ba0c60b38a1f5548fd3c9cbca5';

abstract class _$ConfiguredSettingsJson
    extends $Notifier<Map<String, dynamic>> {
  Map<String, dynamic> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<String, dynamic>, Map<String, dynamic>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, dynamic>, Map<String, dynamic>>,
              Map<String, dynamic>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
