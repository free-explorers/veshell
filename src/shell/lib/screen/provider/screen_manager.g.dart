// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ScreenList provider

@ProviderFor(ScreenManager)
@JsonPersist()
const screenManagerProvider = ScreenManagerProvider._();

/// ScreenList provider
@JsonPersist()
final class ScreenManagerProvider
    extends $NotifierProvider<ScreenManager, ScreenManagerState> {
  /// ScreenList provider
  const ScreenManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'screenManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$screenManagerHash();

  @$internal
  @override
  ScreenManager create() => ScreenManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScreenManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScreenManagerState>(value),
    );
  }
}

String _$screenManagerHash() => r'be288b88d3b132eb919ad7d750a7e6fd0069130f';

/// ScreenList provider

@JsonPersist()
abstract class _$ScreenManagerBase extends $Notifier<ScreenManagerState> {
  ScreenManagerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ScreenManagerState, ScreenManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ScreenManagerState, ScreenManagerState>,
              ScreenManagerState,
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
abstract class _$ScreenManager extends _$ScreenManagerBase {
  /// The default key used by [persist].
  String get key {
    const resolvedKey = "ScreenManager";
    return resolvedKey;
  }

  /// A variant of [persist], for JSON-specific encoding.
  ///
  /// You can override [key] to customize the key used for storage.
  PersistResult persist(
    FutureOr<Storage<String, String>> storage, {
    String? key,
    String Function(ScreenManagerState state)? encode,
    ScreenManagerState Function(String encoded)? decode,
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
            return ScreenManagerState.fromJson(e as Map<String, Object?>);
          },
      options: options,
    );
  }
}
