// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_configuration_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Monitor provider

@ProviderFor(MonitorConfigurationState)
@JsonPersist()
const monitorConfigurationStateProvider = MonitorConfigurationStateFamily._();

/// Monitor provider
@JsonPersist()
final class MonitorConfigurationStateProvider
    extends $NotifierProvider<MonitorConfigurationState, MonitorConfiguration> {
  /// Monitor provider
  const MonitorConfigurationStateProvider._({
    required MonitorConfigurationStateFamily super.from,
    required MonitorId super.argument,
  }) : super(
         retry: null,
         name: r'monitorConfigurationStateProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$monitorConfigurationStateHash();

  @override
  String toString() {
    return r'monitorConfigurationStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MonitorConfigurationState create() => MonitorConfigurationState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MonitorConfiguration value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MonitorConfiguration>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MonitorConfigurationStateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$monitorConfigurationStateHash() =>
    r'8bff617d0c528bf94ba82a2868f33938c9c35938';

/// Monitor provider

@JsonPersist()
final class MonitorConfigurationStateFamily extends $Family
    with
        $ClassFamilyOverride<
          MonitorConfigurationState,
          MonitorConfiguration,
          MonitorConfiguration,
          MonitorConfiguration,
          MonitorId
        > {
  const MonitorConfigurationStateFamily._()
    : super(
        retry: null,
        name: r'monitorConfigurationStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Monitor provider

  @JsonPersist()
  MonitorConfigurationStateProvider call(MonitorId monitorId) =>
      MonitorConfigurationStateProvider._(argument: monitorId, from: this);

  @override
  String toString() => r'monitorConfigurationStateProvider';
}

/// Monitor provider

@JsonPersist()
abstract class _$MonitorConfigurationStateBase
    extends $Notifier<MonitorConfiguration> {
  late final _$args = ref.$arg as MonitorId;
  MonitorId get monitorId => _$args;

  MonitorConfiguration build(MonitorId monitorId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<MonitorConfiguration, MonitorConfiguration>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MonitorConfiguration, MonitorConfiguration>,
              MonitorConfiguration,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

// **************************************************************************
// JsonGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
abstract class _$MonitorConfigurationState
    extends _$MonitorConfigurationStateBase {
  /// The default key used by [persist].
  String get key {
    late final args = monitorId;
    late final resolvedKey = 'MonitorConfigurationState($args)';

    return resolvedKey;
  }

  /// A variant of [persist], for JSON-specific encoding.
  ///
  /// You can override [key] to customize the key used for storage.
  PersistResult persist(
    FutureOr<Storage<String, String>> storage, {
    String? key,
    String Function(MonitorConfiguration state)? encode,
    MonitorConfiguration Function(String encoded)? decode,
    StorageOptions options = const StorageOptions(),
  }) {
    return NotifierPersistX(this).persist<String, String>(
      storage,
      key: key ?? this.key,
      encode: encode ?? $jsonCodex.encode,
      decode:
          decode ??
          (encoded) {
            final e = $jsonCodex.decode(encoded);
            return MonitorConfiguration.fromJson(e as Map<String, Object?>);
          },
      options: options,
    );
  }
}
