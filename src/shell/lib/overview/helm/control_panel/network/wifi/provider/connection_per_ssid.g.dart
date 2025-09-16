// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_per_ssid.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ConnectionPerSsid)
const connectionPerSsidProvider = ConnectionPerSsidFamily._();

final class ConnectionPerSsidProvider
    extends
        $AsyncNotifierProvider<
          ConnectionPerSsid,
          Map<String, NetworkManagerSettingsConnection>
        > {
  const ConnectionPerSsidProvider._({
    required ConnectionPerSsidFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'connectionPerSsidProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$connectionPerSsidHash();

  @override
  String toString() {
    return r'connectionPerSsidProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ConnectionPerSsid create() => ConnectionPerSsid();

  @override
  bool operator ==(Object other) {
    return other is ConnectionPerSsidProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$connectionPerSsidHash() => r'85254507f48abdceab1b6e4d3190f28943fcb28b';

final class ConnectionPerSsidFamily extends $Family
    with
        $ClassFamilyOverride<
          ConnectionPerSsid,
          AsyncValue<Map<String, NetworkManagerSettingsConnection>>,
          Map<String, NetworkManagerSettingsConnection>,
          FutureOr<Map<String, NetworkManagerSettingsConnection>>,
          String
        > {
  const ConnectionPerSsidFamily._()
    : super(
        retry: null,
        name: r'connectionPerSsidProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ConnectionPerSsidProvider call(String deviceAddress) =>
      ConnectionPerSsidProvider._(argument: deviceAddress, from: this);

  @override
  String toString() => r'connectionPerSsidProvider';
}

abstract class _$ConnectionPerSsid
    extends $AsyncNotifier<Map<String, NetworkManagerSettingsConnection>> {
  late final _$args = ref.$arg as String;
  String get deviceAddress => _$args;

  FutureOr<Map<String, NetworkManagerSettingsConnection>> build(
    String deviceAddress,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref
            as $Ref<
              AsyncValue<Map<String, NetworkManagerSettingsConnection>>,
              Map<String, NetworkManagerSettingsConnection>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<Map<String, NetworkManagerSettingsConnection>>,
                Map<String, NetworkManagerSettingsConnection>
              >,
              AsyncValue<Map<String, NetworkManagerSettingsConnection>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
