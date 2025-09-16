// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'icon_theme_setting.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(iconThemeSetting)
const iconThemeSettingProvider = IconThemeSettingProvider._();

final class IconThemeSettingProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  const IconThemeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'iconThemeSettingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$iconThemeSettingHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return iconThemeSetting(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$iconThemeSettingHash() => r'6a7535cb276e7109f28413c1a26c707e11bc0669';
