// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screen_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Screen provider

@ProviderFor(ScreenState)
@JsonPersist()
const screenStateProvider = ScreenStateFamily._();

/// Screen provider
@JsonPersist()
final class ScreenStateProvider extends $NotifierProvider<ScreenState, Screen> {
  /// Screen provider
  const ScreenStateProvider._({
    required ScreenStateFamily super.from,
    required ScreenId super.argument,
  }) : super(
         retry: null,
         name: r'screenStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$screenStateHash();

  @override
  String toString() {
    return r'screenStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ScreenState create() => ScreenState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Screen value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Screen>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScreenStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$screenStateHash() => r'10191b20fcd1a02860a7f2ecc0dee07c8541112d';

/// Screen provider

@JsonPersist()
final class ScreenStateFamily extends $Family
    with $ClassFamilyOverride<ScreenState, Screen, Screen, Screen, ScreenId> {
  const ScreenStateFamily._()
    : super(
        retry: null,
        name: r'screenStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Screen provider

  @JsonPersist()
  ScreenStateProvider call(ScreenId screenId) =>
      ScreenStateProvider._(argument: screenId, from: this);

  @override
  String toString() => r'screenStateProvider';
}

/// Screen provider

@JsonPersist()
abstract class _$ScreenStateBase extends $Notifier<Screen> {
  late final _$args = ref.$arg as ScreenId;
  ScreenId get screenId => _$args;

  Screen build(ScreenId screenId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<Screen, Screen>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Screen, Screen>,
              Screen,
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
abstract class _$ScreenState extends _$ScreenStateBase {
  /// The default key used by [persist].
  String get key {
    late final args = screenId;
    late final resolvedKey = 'ScreenState($args)';

    return resolvedKey;
  }

  /// A variant of [persist], for JSON-specific encoding.
  ///
  /// You can override [key] to customize the key used for storage.
  PersistResult persist(
    FutureOr<Storage<String, String>> storage, {
    String? key,
    String Function(Screen state)? encode,
    Screen Function(String encoded)? decode,
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
            return Screen.fromJson(e as Map<String, Object?>);
          },
      options: options,
    );
  }
}
