// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nm_device_removed.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NmDeviceRemoved)
const nmDeviceRemovedProvider = NmDeviceRemovedProvider._();

final class NmDeviceRemovedProvider
    extends
        $FunctionalProvider<
          AsyncValue<NetworkManagerDevice>,
          NetworkManagerDevice,
          Stream<NetworkManagerDevice>
        >
    with
        $FutureModifier<NetworkManagerDevice>,
        $StreamProvider<NetworkManagerDevice> {
  const NmDeviceRemovedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nmDeviceRemovedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nmDeviceRemovedHash();

  @$internal
  @override
  $StreamProviderElement<NetworkManagerDevice> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<NetworkManagerDevice> create(Ref ref) {
    return NmDeviceRemoved(ref);
  }
}

String _$nmDeviceRemovedHash() => r'8c6efda6b9def49fa9b9eebd51cd5015418f465f';
