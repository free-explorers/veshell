// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../platform_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$textInputEventStreamByIdHash() =>
    r'386b8f5b60e3c46d7ee761d72eb165fd631e2fab';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

typedef _TextInputEventStreamByIdRef = StreamProviderRef<dynamic>;

/// See also [_textInputEventStreamById].
@ProviderFor(_textInputEventStreamById)
const _textInputEventStreamByIdProvider = _TextInputEventStreamByIdFamily();

/// See also [_textInputEventStreamById].
class _TextInputEventStreamByIdFamily extends Family<AsyncValue<dynamic>> {
  /// See also [_textInputEventStreamById].
  const _TextInputEventStreamByIdFamily();

  /// See also [_textInputEventStreamById].
  _TextInputEventStreamByIdProvider call(
    int viewId,
  ) {
    return _TextInputEventStreamByIdProvider(
      viewId,
    );
  }

  @override
  _TextInputEventStreamByIdProvider getProviderOverride(
    covariant _TextInputEventStreamByIdProvider provider,
  ) {
    return call(
      provider.viewId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'_textInputEventStreamByIdProvider';
}

/// See also [_textInputEventStreamById].
class _TextInputEventStreamByIdProvider extends StreamProvider<dynamic> {
  /// See also [_textInputEventStreamById].
  _TextInputEventStreamByIdProvider(
    this.viewId,
  ) : super.internal(
          (ref) => _textInputEventStreamById(
            ref,
            viewId,
          ),
          from: _textInputEventStreamByIdProvider,
          name: r'_textInputEventStreamByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$textInputEventStreamByIdHash,
          dependencies: _TextInputEventStreamByIdFamily._dependencies,
          allTransitiveDependencies:
              _TextInputEventStreamByIdFamily._allTransitiveDependencies,
        );

  final int viewId;

  @override
  bool operator ==(Object other) {
    return other is _TextInputEventStreamByIdProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

String _$textInputEventStreamHash() =>
    r'a1c50514a750715c755720256bb540d7649ddc1a';
typedef TextInputEventStreamRef = FutureProviderRef<TextInputEventType>;

/// See also [textInputEventStream].
@ProviderFor(textInputEventStream)
const textInputEventStreamProvider = TextInputEventStreamFamily();

/// See also [textInputEventStream].
class TextInputEventStreamFamily
    extends Family<AsyncValue<TextInputEventType>> {
  /// See also [textInputEventStream].
  const TextInputEventStreamFamily();

  /// See also [textInputEventStream].
  TextInputEventStreamProvider call(
    int viewId,
  ) {
    return TextInputEventStreamProvider(
      viewId,
    );
  }

  @override
  TextInputEventStreamProvider getProviderOverride(
    covariant TextInputEventStreamProvider provider,
  ) {
    return call(
      provider.viewId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'textInputEventStreamProvider';
}

/// See also [textInputEventStream].
class TextInputEventStreamProvider extends FutureProvider<TextInputEventType> {
  /// See also [textInputEventStream].
  TextInputEventStreamProvider(
    this.viewId,
  ) : super.internal(
          (ref) => textInputEventStream(
            ref,
            viewId,
          ),
          from: textInputEventStreamProvider,
          name: r'textInputEventStreamProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$textInputEventStreamHash,
          dependencies: TextInputEventStreamFamily._dependencies,
          allTransitiveDependencies:
              TextInputEventStreamFamily._allTransitiveDependencies,
        );

  final int viewId;

  @override
  bool operator ==(Object other) {
    return other is TextInputEventStreamProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

String _$windowMappedStreamHash() =>
    r'406e042fd1cca4b6529cf742bdffe5b4ccdd8c1d';

/// See also [WindowMappedStream].
@ProviderFor(WindowMappedStream)
final windowMappedStreamProvider =
    StreamNotifierProvider<WindowMappedStream, int>.internal(
  WindowMappedStream.new,
  name: r'windowMappedStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$windowMappedStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WindowMappedStream = StreamNotifier<int>;
String _$windowUnmappedStreamHash() =>
    r'27c0e325f702f372c2022ac085b09374437e50c1';

/// See also [WindowUnmappedStream].
@ProviderFor(WindowUnmappedStream)
final windowUnmappedStreamProvider =
    StreamNotifierProvider<WindowUnmappedStream, int>.internal(
  WindowUnmappedStream.new,
  name: r'windowUnmappedStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$windowUnmappedStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$WindowUnmappedStream = StreamNotifier<int>;
String _$platformApiHash() => r'4bbfd717c0a2bbb9c36fc8a95da5442bc7355168';

/// See also [PlatformApi].
@ProviderFor(PlatformApi)
final platformApiProvider =
    NotifierProvider<PlatformApi, PlatformApiState>.internal(
  PlatformApi.new,
  name: r'platformApiProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$platformApiHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PlatformApi = Notifier<PlatformApiState>;
// ignore_for_file: unnecessary_raw_strings, subtype_of_sealed_class, invalid_use_of_internal_member, do_not_use_environment, prefer_const_constructors, public_member_api_docs, avoid_private_typedef_functions
