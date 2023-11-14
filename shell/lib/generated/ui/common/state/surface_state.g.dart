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
    int viewId,
  ) : this._internal(
          (ref) => surfaceWidget(
            ref as SurfaceWidgetRef,
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
          viewId: viewId,
        );

  SurfaceWidgetProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.viewId,
  }) : super.internal();

  final int viewId;

  @override
  Override overrideWith(
    Surface Function(SurfaceWidgetRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SurfaceWidgetProvider._internal(
        (ref) => create(ref as SurfaceWidgetRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        viewId: viewId,
      ),
    );
  }

  @override
  ProviderElement<Surface> createElement() {
    return _SurfaceWidgetProviderElement(this);
  }

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

mixin SurfaceWidgetRef on ProviderRef<Surface> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _SurfaceWidgetProviderElement extends ProviderElement<Surface>
    with SurfaceWidgetRef {
  _SurfaceWidgetProviderElement(super.provider);

  @override
  int get viewId => (origin as SurfaceWidgetProvider).viewId;
}

String _$surfaceStatesHash() => r'9d292503b8280003f333d367754673ab0187a5c1';

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
    int viewId,
  ) : this._internal(
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
          viewId: viewId,
        );

  SurfaceStatesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.viewId,
  }) : super.internal();

  final int viewId;

  @override
  SurfaceState runNotifierBuild(
    covariant SurfaceStates notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(SurfaceStates Function() create) {
    return ProviderOverride(
      origin: this,
      override: SurfaceStatesProvider._internal(
        () => create()..viewId = viewId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        viewId: viewId,
      ),
    );
  }

  @override
  NotifierProviderElement<SurfaceStates, SurfaceState> createElement() {
    return _SurfaceStatesProviderElement(this);
  }

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
}

mixin SurfaceStatesRef on NotifierProviderRef<SurfaceState> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _SurfaceStatesProviderElement
    extends NotifierProviderElement<SurfaceStates, SurfaceState>
    with SurfaceStatesRef {
  _SurfaceStatesProviderElement(super.provider);

  @override
  int get viewId => (origin as SurfaceStatesProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
