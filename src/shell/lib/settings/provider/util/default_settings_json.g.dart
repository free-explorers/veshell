// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_settings_json.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DefaultSettingsJson)
const defaultSettingsJsonProvider = DefaultSettingsJsonProvider._();

final class DefaultSettingsJsonProvider
    extends $NotifierProvider<DefaultSettingsJson, Map<String, dynamic>> {
  const DefaultSettingsJsonProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultSettingsJsonProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultSettingsJsonHash();

  @$internal
  @override
  DefaultSettingsJson create() => DefaultSettingsJson();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, dynamic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, dynamic>>(value),
    );
  }
}

String _$defaultSettingsJsonHash() =>
    r'17d3cdcf31062a373ede639ba595cb7f345defd1';

abstract class _$DefaultSettingsJson extends $Notifier<Map<String, dynamic>> {
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
