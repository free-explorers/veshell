// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merged_settings_json.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MergedSettingsJson)
const mergedSettingsJsonProvider = MergedSettingsJsonProvider._();

final class MergedSettingsJsonProvider
    extends $NotifierProvider<MergedSettingsJson, Map<String, dynamic>> {
  const MergedSettingsJsonProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mergedSettingsJsonProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mergedSettingsJsonHash();

  @$internal
  @override
  MergedSettingsJson create() => MergedSettingsJson();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, dynamic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, dynamic>>(value),
    );
  }
}

String _$mergedSettingsJsonHash() =>
    r'd6d6d6c083857d6fdf5b99dd93f1399d9b961681';

abstract class _$MergedSettingsJson extends $Notifier<Map<String, dynamic>> {
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
