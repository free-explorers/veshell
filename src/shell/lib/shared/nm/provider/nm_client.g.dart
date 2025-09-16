// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nm_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NmClient)
const nmClientProvider = NmClientProvider._();

final class NmClientProvider
    extends
        $FunctionalProvider<
          AsyncValue<NetworkManagerClient>,
          NetworkManagerClient,
          FutureOr<NetworkManagerClient>
        >
    with
        $FutureModifier<NetworkManagerClient>,
        $FutureProvider<NetworkManagerClient> {
  const NmClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nmClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nmClientHash();

  @$internal
  @override
  $FutureProviderElement<NetworkManagerClient> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NetworkManagerClient> create(Ref ref) {
    return NmClient(ref);
  }
}

String _$nmClientHash() => r'56799e22feaca89b7d0e79f3b475d2b07d5e6718';
