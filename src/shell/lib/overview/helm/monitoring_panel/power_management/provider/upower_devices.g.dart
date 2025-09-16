// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upower_devices.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(upowerDevices)
const upowerDevicesProvider = UpowerDevicesProvider._();

final class UpowerDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<UPowerDevice>>,
          List<UPowerDevice>,
          FutureOr<List<UPowerDevice>>
        >
    with
        $FutureModifier<List<UPowerDevice>>,
        $FutureProvider<List<UPowerDevice>> {
  const UpowerDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upowerDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upowerDevicesHash();

  @$internal
  @override
  $FutureProviderElement<List<UPowerDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<UPowerDevice>> create(Ref ref) {
    return upowerDevices(ref);
  }
}

String _$upowerDevicesHash() => r'18aba88e7ab7cb086b98d5b336b12f8c0b0d2c11';
