// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bluez_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BluezClient)
const bluezClientProvider = BluezClientProvider._();

final class BluezClientProvider
    extends
        $FunctionalProvider<
          AsyncValue<BlueZClient>,
          BlueZClient,
          FutureOr<BlueZClient>
        >
    with $FutureModifier<BlueZClient>, $FutureProvider<BlueZClient> {
  const BluezClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bluezClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bluezClientHash();

  @$internal
  @override
  $FutureProviderElement<BlueZClient> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BlueZClient> create(Ref ref) {
    return BluezClient(ref);
  }
}

String _$bluezClientHash() => r'23284ea52bcc336a9cd0718a12861554856259cb';
