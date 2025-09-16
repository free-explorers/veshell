// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'any_upower_device.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(anyUpowerDevice)
const anyUpowerDeviceProvider = AnyUpowerDeviceProvider._();

final class AnyUpowerDeviceProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const AnyUpowerDeviceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'anyUpowerDeviceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$anyUpowerDeviceHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return anyUpowerDevice(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$anyUpowerDeviceHash() => r'a84a3fa44f3bd860e5ea37142443e14978935390';
