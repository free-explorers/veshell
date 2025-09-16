// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_color_setting.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(themeColorSetting)
const themeColorSettingProvider = ThemeColorSettingProvider._();

final class ThemeColorSettingProvider
    extends $FunctionalProvider<Color, Color, Color>
    with $Provider<Color> {
  const ThemeColorSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeColorSettingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeColorSettingHash();

  @$internal
  @override
  $ProviderElement<Color> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Color create(Ref ref) {
    return themeColorSetting(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Color value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Color>(value),
    );
  }
}

String _$themeColorSettingHash() => r'4ba5294d7560be061d2e3c84fbfc31a75140e891';
