// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wifi_access_point_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WifiAccessPointList)
const wifiAccessPointListProvider = WifiAccessPointListFamily._();

final class WifiAccessPointListProvider
    extends $NotifierProvider<WifiAccessPointList, List<WifiAccessPoint>> {
  const WifiAccessPointListProvider._({
    required WifiAccessPointListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'wifiAccessPointListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$wifiAccessPointListHash();

  @override
  String toString() {
    return r'wifiAccessPointListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WifiAccessPointList create() => WifiAccessPointList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<WifiAccessPoint> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<WifiAccessPoint>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WifiAccessPointListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$wifiAccessPointListHash() =>
    r'b0010e4e916cc7a7c6075a28842098d4d8a945bf';

final class WifiAccessPointListFamily extends $Family
    with
        $ClassFamilyOverride<
          WifiAccessPointList,
          List<WifiAccessPoint>,
          List<WifiAccessPoint>,
          List<WifiAccessPoint>,
          String
        > {
  const WifiAccessPointListFamily._()
    : super(
        retry: null,
        name: r'wifiAccessPointListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WifiAccessPointListProvider call(String address) =>
      WifiAccessPointListProvider._(argument: address, from: this);

  @override
  String toString() => r'wifiAccessPointListProvider';
}

abstract class _$WifiAccessPointList extends $Notifier<List<WifiAccessPoint>> {
  late final _$args = ref.$arg as String;
  String get address => _$args;

  List<WifiAccessPoint> build(String address);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<List<WifiAccessPoint>, List<WifiAccessPoint>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<WifiAccessPoint>, List<WifiAccessPoint>>,
              List<WifiAccessPoint>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
