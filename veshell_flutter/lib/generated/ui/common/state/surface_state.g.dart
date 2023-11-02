// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/common/state/surface_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$surfaceWidgetHash() => r'6f6989b8106340048dafbdd39365add866a55f8f';

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

typedef SurfaceWidgetRef = ProviderRef<Surface>;

/// See also [surfaceWidget].
@ProviderFor(surfaceWidget)
const surfaceWidgetProvider = SurfaceWidgetFamily();

/// See also [surfaceWidget].
class SurfaceWidgetFamily extends Family<Surface> {
  /// See also [surfaceWidget].
  const SurfaceWidgetFamily();

  /// See also [surfaceWidget].
  SurfaceWidgetProvider call(
    int viewId,
  ) {
    return SurfaceWidgetProvider(
      viewId,
    );
  }

  @override
  SurfaceWidgetProvider getProviderOverride(
    covariant SurfaceWidgetProvider provider,
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
  String? get name => r'surfaceWidgetProvider';
}

/// See also [surfaceWidget].
class SurfaceWidgetProvider extends Provider<Surface> {
  /// See also [surfaceWidget].
  SurfaceWidgetProvider(
    this.viewId,
  ) : super.internal(
          (ref) => surfaceWidget(
            ref,
            viewId,
          ),
          from: surfaceWidgetProvider,
          name: r'surfaceWidgetProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$surfaceWidgetHash,
          dependencies: SurfaceWidgetFamily._dependencies,
          allTransitiveDependencies:
              SurfaceWidgetFamily._allTransitiveDependencies,
        );

  final int viewId;

  @override
  bool operator ==(Object other) {
    return other is SurfaceWidgetProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

String _$surfaceStatesHash() => r'5caa225a3c1de7b3e468b079377ed5e9c7fee3d8';

abstract class _$SurfaceStates extends BuildlessNotifier<SurfaceState> {
  late final int viewId;

  SurfaceState build(
    int viewId,
  );
}

/// See also [SurfaceStates].
@ProviderFor(SurfaceStates)
const surfaceStatesProvider = SurfaceStatesFamily();

/// See also [SurfaceStates].
class SurfaceStatesFamily extends Family<SurfaceState> {
  /// See also [SurfaceStates].
  const SurfaceStatesFamily();

  /// See also [SurfaceStates].
  SurfaceStatesProvider call(
    int viewId,
  ) {
    return SurfaceStatesProvider(
      viewId,
    );
  }

  @override
  SurfaceStatesProvider getProviderOverride(
    covariant SurfaceStatesProvider provider,
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
  String? get name => r'surfaceStatesProvider';
}

/// See also [SurfaceStates].
class SurfaceStatesProvider
    extends NotifierProviderImpl<SurfaceStates, SurfaceState> {
  /// See also [SurfaceStates].
  SurfaceStatesProvider(
    this.viewId,
  ) : super.internal(
          () => SurfaceStates()..viewId = viewId,
          from: surfaceStatesProvider,
          name: r'surfaceStatesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$surfaceStatesHash,
          dependencies: SurfaceStatesFamily._dependencies,
          allTransitiveDependencies:
              SurfaceStatesFamily._allTransitiveDependencies,
        );

  final int viewId;

  @override
  bool operator ==(Object other) {
    return other is SurfaceStatesProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }

  @override
  SurfaceState runNotifierBuild(
    covariant SurfaceStates notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }
}
// ignore_for_file: unnecessary_raw_strings, subtype_of_sealed_class, invalid_use_of_internal_member, do_not_use_environment, prefer_const_constructors, public_member_api_docs, avoid_private_typedef_functions
