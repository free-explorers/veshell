// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upower_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UpowerClient)
const upowerClientProvider = UpowerClientProvider._();

final class UpowerClientProvider
    extends $AsyncNotifierProvider<UpowerClient, UPowerClient> {
  const UpowerClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upowerClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upowerClientHash();

  @$internal
  @override
  UpowerClient create() => UpowerClient();
}

String _$upowerClientHash() => r'23564edeabce3bafb624433ec3c43c6f77cae8a5';

abstract class _$UpowerClient extends $AsyncNotifier<UPowerClient> {
  FutureOr<UPowerClient> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<UPowerClient>, UPowerClient>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UPowerClient>, UPowerClient>,
              AsyncValue<UPowerClient>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
