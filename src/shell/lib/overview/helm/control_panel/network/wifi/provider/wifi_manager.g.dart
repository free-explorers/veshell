// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wifi_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WifiManager)
const wifiManagerProvider = WifiManagerFamily._();

final class WifiManagerProvider
    extends $NotifierProvider<WifiManager, WifiManagerState> {
  const WifiManagerProvider._({
    required WifiManagerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'wifiManagerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$wifiManagerHash();

  @override
  String toString() {
    return r'wifiManagerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WifiManager create() => WifiManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WifiManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WifiManagerState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WifiManagerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$wifiManagerHash() => r'3514903f351a0f8a831913601745ad9dd3abc2d1';

final class WifiManagerFamily extends $Family
    with
        $ClassFamilyOverride<
          WifiManager,
          WifiManagerState,
          WifiManagerState,
          WifiManagerState,
          String
        > {
  const WifiManagerFamily._()
    : super(
        retry: null,
        name: r'wifiManagerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  WifiManagerProvider call(String address) =>
      WifiManagerProvider._(argument: address, from: this);

  @override
  String toString() => r'wifiManagerProvider';
}

abstract class _$WifiManager extends $Notifier<WifiManagerState> {
  late final _$args = ref.$arg as String;
  String get address => _$args;

  WifiManagerState build(String address);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<WifiManagerState, WifiManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WifiManagerState, WifiManagerState>,
              WifiManagerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
