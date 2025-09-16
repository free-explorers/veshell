// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_setting_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MonitorSettingState)
const monitorSettingStateProvider = MonitorSettingStateFamily._();

final class MonitorSettingStateProvider
    extends $NotifierProvider<MonitorSettingState, MonitorSetting> {
  const MonitorSettingStateProvider._({
    required MonitorSettingStateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'monitorSettingStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monitorSettingStateHash();

  @override
  String toString() {
    return r'monitorSettingStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MonitorSettingState create() => MonitorSettingState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MonitorSetting value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MonitorSetting>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MonitorSettingStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monitorSettingStateHash() =>
    r'8005483b5b2ef3f098953be60e383f8308790a4c';

final class MonitorSettingStateFamily extends $Family
    with
        $ClassFamilyOverride<
          MonitorSettingState,
          MonitorSetting,
          MonitorSetting,
          MonitorSetting,
          String
        > {
  const MonitorSettingStateFamily._()
    : super(
        retry: null,
        name: r'monitorSettingStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MonitorSettingStateProvider call(String monitorId) =>
      MonitorSettingStateProvider._(argument: monitorId, from: this);

  @override
  String toString() => r'monitorSettingStateProvider';
}

abstract class _$MonitorSettingState extends $Notifier<MonitorSetting> {
  late final _$args = ref.$arg as String;
  String get monitorId => _$args;

  MonitorSetting build(String monitorId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<MonitorSetting, MonitorSetting>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MonitorSetting, MonitorSetting>,
              MonitorSetting,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
