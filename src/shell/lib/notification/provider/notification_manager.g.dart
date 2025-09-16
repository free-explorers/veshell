// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NotificationManager)
@JsonPersist()
const notificationManagerProvider = NotificationManagerProvider._();

@JsonPersist()
final class NotificationManagerProvider
    extends $NotifierProvider<NotificationManager, NotificationManagerState> {
  const NotificationManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationManagerHash();

  @$internal
  @override
  NotificationManager create() => NotificationManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationManagerState>(value),
    );
  }
}

String _$notificationManagerHash() =>
    r'f2fac382f31b3677e74af80e4c6c90a7c44bfa46';

@JsonPersist()
abstract class _$NotificationManagerBase
    extends $Notifier<NotificationManagerState> {
  NotificationManagerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<NotificationManagerState, NotificationManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NotificationManagerState, NotificationManagerState>,
              NotificationManagerState,
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
abstract class _$NotificationManager extends _$NotificationManagerBase {
  /// The default key used by [persist].
  String get key {
    const resolvedKey = "NotificationManager";
    return resolvedKey;
  }

  /// A variant of [persist], for JSON-specific encoding.
  ///
  /// You can override [key] to customize the key used for storage.
  PersistResult persist(
    FutureOr<Storage<String, String>> storage, {
    String? key,
    String Function(NotificationManagerState state)? encode,
    NotificationManagerState Function(String encoded)? decode,
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
            return NotificationManagerState.fromJson(e as Map<String, Object?>);
          },
      options: options,
    );
  }
}
