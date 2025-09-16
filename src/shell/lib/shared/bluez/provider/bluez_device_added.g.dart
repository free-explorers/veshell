// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bluez_device_added.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BluezDeviceAdded)
const bluezDeviceAddedProvider = BluezDeviceAddedProvider._();

final class BluezDeviceAddedProvider
    extends
        $FunctionalProvider<
          AsyncValue<BlueZDevice>,
          BlueZDevice,
          Stream<BlueZDevice>
        >
    with $FutureModifier<BlueZDevice>, $StreamProvider<BlueZDevice> {
  const BluezDeviceAddedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bluezDeviceAddedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bluezDeviceAddedHash();

  @$internal
  @override
  $StreamProviderElement<BlueZDevice> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<BlueZDevice> create(Ref ref) {
    return BluezDeviceAdded(ref);
  }
}

String _$bluezDeviceAddedHash() => r'b1f0e71cdf1f69762cbef952ee04670ce6631d1b';
