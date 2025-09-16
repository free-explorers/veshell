// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Window manager

@ProviderFor(WindowManager)
@JsonPersist()
const windowManagerProvider = WindowManagerProvider._();

/// Window manager
@JsonPersist()
final class WindowManagerProvider
    extends $NotifierProvider<WindowManager, WindowManagerState> {
  /// Window manager
  const WindowManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowManagerHash();

  @$internal
  @override
  WindowManager create() => WindowManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WindowManagerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WindowManagerState>(value),
    );
  }
}

String _$windowManagerHash() => r'df2a4b02b3d70c82a2391c7cf9103ba6721f1b2d';

/// Window manager

@JsonPersist()
abstract class _$WindowManagerBase extends $Notifier<WindowManagerState> {
  WindowManagerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<WindowManagerState, WindowManagerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WindowManagerState, WindowManagerState>,
              WindowManagerState,
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
abstract class _$WindowManager extends _$WindowManagerBase {
  /// The default key used by [persist].
  String get key {
    const resolvedKey = "WindowManager";
    return resolvedKey;
  }

  /// A variant of [persist], for JSON-specific encoding.
  ///
  /// You can override [key] to customize the key used for storage.
  PersistResult persist(
    FutureOr<Storage<String, String>> storage, {
    String? key,
    String Function(WindowManagerState state)? encode,
    WindowManagerState Function(String encoded)? decode,
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
            return WindowManagerState.fromJson(e as Map<String, Object?>);
          },
      options: options,
    );
  }
}
