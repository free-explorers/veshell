// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upower_battery_device.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(upowerBatteryDevice)
const upowerBatteryDeviceProvider = UpowerBatteryDeviceProvider._();

final class UpowerBatteryDeviceProvider
    extends
        $FunctionalProvider<
          AsyncValue<UPowerDevice?>,
          UPowerDevice?,
          FutureOr<UPowerDevice?>
        >
    with $FutureModifier<UPowerDevice?>, $FutureProvider<UPowerDevice?> {
  const UpowerBatteryDeviceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upowerBatteryDeviceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upowerBatteryDeviceHash();

  @$internal
  @override
  $FutureProviderElement<UPowerDevice?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UPowerDevice?> create(Ref ref) {
    return upowerBatteryDevice(ref);
  }
}

String _$upowerBatteryDeviceHash() =>
    r'123d2943ef2cb253607cf39c708121f3498bb982';
