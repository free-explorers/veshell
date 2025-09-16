// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bluez_device_removed.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BluezDeviceRemoved)
const bluezDeviceRemovedProvider = BluezDeviceRemovedProvider._();

final class BluezDeviceRemovedProvider
    extends
        $FunctionalProvider<
          AsyncValue<BlueZDevice>,
          BlueZDevice,
          Stream<BlueZDevice>
        >
    with $FutureModifier<BlueZDevice>, $StreamProvider<BlueZDevice> {
  const BluezDeviceRemovedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bluezDeviceRemovedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bluezDeviceRemovedHash();

  @$internal
  @override
  $StreamProviderElement<BlueZDevice> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BlueZDevice> create(Ref ref) {
    return BluezDeviceRemoved(ref);
  }
}

String _$bluezDeviceRemovedHash() =>
    r'ea1d9cd37adb76363603bdee9fb4330d39b60ee6';
