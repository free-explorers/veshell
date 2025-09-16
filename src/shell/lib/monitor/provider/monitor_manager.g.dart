// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MonitorManager)
@JsonPersist()
const monitorManagerProvider = MonitorManagerProvider._();

@JsonPersist()
final class MonitorManagerProvider
    extends $NotifierProvider<MonitorManager, MonitorManagerState> {
  const MonitorManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'monitorManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$monitorManagerHash();

  @$internal
  @override
  MonitorManager create() => MonitorManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MonitorManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MonitorManagerState>(value),
    );
  }
}

String _$monitorManagerHash() => r'30ad076697ba6270bde7b28e2985ff51f70658da';

@JsonPersist()
abstract class _$MonitorManagerBase extends $Notifier<MonitorManagerState> {
  MonitorManagerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<MonitorManagerState, MonitorManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MonitorManagerState, MonitorManagerState>,
              MonitorManagerState,
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
abstract class _$MonitorManager extends _$MonitorManagerBase {
  /// The default key used by [persist].
  String get key {
    const resolvedKey = "MonitorManager";
    return resolvedKey;
  }

  /// A variant of [persist], for JSON-specific encoding.
  ///
  /// You can override [key] to customize the key used for storage.
  PersistResult persist(
    FutureOr<Storage<String, String>> storage, {
    String? key,
    String Function(MonitorManagerState state)? encode,
    MonitorManagerState Function(String encoded)? decode,
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
            return MonitorManagerState.fromJson(e as Map<String, Object?>);
          },
      options: options,
    );
  }
}
