// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hotkeys_setting.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(hotkeysSetting)
const hotkeysSettingProvider = HotkeysSettingProvider._();

final class HotkeysSettingProvider
    extends
        $FunctionalProvider<
          Map<String, LogicalKeySet>,
          Map<String, LogicalKeySet>,
          Map<String, LogicalKeySet>
        >
    with $Provider<Map<String, LogicalKeySet>> {
  const HotkeysSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hotkeysSettingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hotkeysSettingHash();

  @$internal
  @override
  $ProviderElement<Map<String, LogicalKeySet>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, LogicalKeySet> create(Ref ref) {
    return hotkeysSetting(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, LogicalKeySet> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, LogicalKeySet>>(value),
    );
  }
}

String _$hotkeysSettingHash() => r'8e9392ed4469003dabe4177c3a6a53470e81b04f';
