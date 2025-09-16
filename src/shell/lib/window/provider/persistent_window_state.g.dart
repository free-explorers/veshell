// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'persistent_window_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Workspace provider

@ProviderFor(PersistentWindowState)
@JsonPersist()
const persistentWindowStateProvider = PersistentWindowStateFamily._();

/// Workspace provider
@JsonPersist()
final class PersistentWindowStateProvider
    extends $NotifierProvider<PersistentWindowState, PersistentWindow> {
  /// Workspace provider
  const PersistentWindowStateProvider._({
    required PersistentWindowStateFamily super.from,
    required PersistentWindowId super.argument,
  }) : super(
         retry: null,
         name: r'persistentWindowStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$persistentWindowStateHash();

  @override
  String toString() {
    return r'persistentWindowStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PersistentWindowState create() => PersistentWindowState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersistentWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersistentWindow>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PersistentWindowStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$persistentWindowStateHash() =>
    r'64f339bb51711c599adb31751277c105637e094a';

/// Workspace provider

@JsonPersist()
final class PersistentWindowStateFamily extends $Family
    with
        $ClassFamilyOverride<
          PersistentWindowState,
          PersistentWindow,
          PersistentWindow,
          PersistentWindow,
          PersistentWindowId
        > {
  const PersistentWindowStateFamily._()
    : super(
        retry: null,
        name: r'persistentWindowStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Workspace provider

  @JsonPersist()
  PersistentWindowStateProvider call(PersistentWindowId windowId) =>
      PersistentWindowStateProvider._(argument: windowId, from: this);

  @override
  String toString() => r'persistentWindowStateProvider';
}

/// Workspace provider

@JsonPersist()
abstract class _$PersistentWindowStateBase extends $Notifier<PersistentWindow> {
  late final _$args = ref.$arg as PersistentWindowId;
  PersistentWindowId get windowId => _$args;

  PersistentWindow build(PersistentWindowId windowId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<PersistentWindow, PersistentWindow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PersistentWindow, PersistentWindow>,
              PersistentWindow,
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
abstract class _$PersistentWindowState extends _$PersistentWindowStateBase {
  /// The default key used by [persist].
  String get key {
    late final args = windowId;
    late final resolvedKey = 'PersistentWindowState($args)';

    return resolvedKey;
  }

  /// A variant of [persist], for JSON-specific encoding.
  ///
  /// You can override [key] to customize the key used for storage.
  PersistResult persist(
    FutureOr<Storage<String, String>> storage, {
    String? key,
    String Function(PersistentWindow state)? encode,
    PersistentWindow Function(String encoded)? decode,
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
            return PersistentWindow.fromJson(e as Map<String, Object?>);
          },
      options: options,
    );
  }
}
