// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nm_device_added.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NmDeviceAdded)
const nmDeviceAddedProvider = NmDeviceAddedProvider._();

final class NmDeviceAddedProvider
    extends
        $FunctionalProvider<
          AsyncValue<NetworkManagerDevice>,
          NetworkManagerDevice,
          Stream<NetworkManagerDevice>
        >
    with
        $FutureModifier<NetworkManagerDevice>,
        $StreamProvider<NetworkManagerDevice> {
  const NmDeviceAddedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nmDeviceAddedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nmDeviceAddedHash();

  @$internal
  @override
  $StreamProviderElement<NetworkManagerDevice> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<NetworkManagerDevice> create(Ref ref) {
    return NmDeviceAdded(ref);
  }
}

String _$nmDeviceAddedHash() => r'21d887fcde30c79fbcbc3bf4579a5a1127d1e61a';
