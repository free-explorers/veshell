// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_setting_json.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MonitorSettingJson)
const monitorSettingJsonProvider = MonitorSettingJsonFamily._();

final class MonitorSettingJsonProvider
    extends $NotifierProvider<MonitorSettingJson, Map<String, dynamic>> {
  const MonitorSettingJsonProvider._({
    required MonitorSettingJsonFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'monitorSettingJsonProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monitorSettingJsonHash();

  @override
  String toString() {
    return r'monitorSettingJsonProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MonitorSettingJson create() => MonitorSettingJson();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, dynamic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, dynamic>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MonitorSettingJsonProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monitorSettingJsonHash() =>
    r'c0ce320357683d6c6232b01d952e09b2b59e213b';

final class MonitorSettingJsonFamily extends $Family
    with
        $ClassFamilyOverride<
          MonitorSettingJson,
          Map<String, dynamic>,
          Map<String, dynamic>,
          Map<String, dynamic>,
          String
        > {
  const MonitorSettingJsonFamily._()
    : super(
        retry: null,
        name: r'monitorSettingJsonProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MonitorSettingJsonProvider call(String monitorId) =>
      MonitorSettingJsonProvider._(argument: monitorId, from: this);

  @override
  String toString() => r'monitorSettingJsonProvider';
}

abstract class _$MonitorSettingJson extends $Notifier<Map<String, dynamic>> {
  late final _$args = ref.$arg as String;
  String get monitorId => _$args;

  Map<String, dynamic> build(String monitorId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<Map<String, dynamic>, Map<String, dynamic>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, dynamic>, Map<String, dynamic>>,
              Map<String, dynamic>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
