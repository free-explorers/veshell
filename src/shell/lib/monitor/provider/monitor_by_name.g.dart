// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_by_name.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provide list of plugged Monitors

@ProviderFor(MonitorByName)
const monitorByNameProvider = MonitorByNameFamily._();

/// Provide list of plugged Monitors
final class MonitorByNameProvider
    extends $NotifierProvider<MonitorByName, Monitor?> {
  /// Provide list of plugged Monitors
  const MonitorByNameProvider._({
    required MonitorByNameFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'monitorByNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monitorByNameHash();

  @override
  String toString() {
    return r'monitorByNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MonitorByName create() => MonitorByName();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Monitor? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Monitor?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MonitorByNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monitorByNameHash() => r'b5b74ee17d4242ff037c9b452234f73ef458476c';

/// Provide list of plugged Monitors

final class MonitorByNameFamily extends $Family
    with
        $ClassFamilyOverride<
          MonitorByName,
          Monitor?,
          Monitor?,
          Monitor?,
          String
        > {
  const MonitorByNameFamily._()
    : super(
        retry: null,
        name: r'monitorByNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provide list of plugged Monitors

  MonitorByNameProvider call(String monitorName) =>
      MonitorByNameProvider._(argument: monitorName, from: this);

  @override
  String toString() => r'monitorByNameProvider';
}

/// Provide list of plugged Monitors

abstract class _$MonitorByName extends $Notifier<Monitor?> {
  late final _$args = ref.$arg as String;
  String get monitorName => _$args;

  Monitor? build(String monitorName);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<Monitor?, Monitor?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Monitor?, Monitor?>,
              Monitor?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
