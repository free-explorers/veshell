// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/common/state/xdg_surface_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$xdgSurfaceStatesHash() => r'def7803523154cdaa9fcb46a8bf7439a682cc0ca';

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

abstract class _$XdgSurfaceStates extends BuildlessNotifier<XdgSurfaceState> {
  late final int viewId;

  XdgSurfaceState build(
    int viewId,
  );
}

/// See also [XdgSurfaceStates].
@ProviderFor(XdgSurfaceStates)
const xdgSurfaceStatesProvider = XdgSurfaceStatesFamily();

/// See also [XdgSurfaceStates].
class XdgSurfaceStatesFamily extends Family<XdgSurfaceState> {
  /// See also [XdgSurfaceStates].
  const XdgSurfaceStatesFamily();

  /// See also [XdgSurfaceStates].
  XdgSurfaceStatesProvider call(
    int viewId,
  ) {
    return XdgSurfaceStatesProvider(
      viewId,
    );
  }

  @override
  XdgSurfaceStatesProvider getProviderOverride(
    covariant XdgSurfaceStatesProvider provider,
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
  String? get name => r'xdgSurfaceStatesProvider';
}

/// See also [XdgSurfaceStates].
class XdgSurfaceStatesProvider
    extends NotifierProviderImpl<XdgSurfaceStates, XdgSurfaceState> {
  /// See also [XdgSurfaceStates].
  XdgSurfaceStatesProvider(
    int viewId,
  ) : this._internal(
          () => XdgSurfaceStates()..viewId = viewId,
          from: xdgSurfaceStatesProvider,
          name: r'xdgSurfaceStatesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$xdgSurfaceStatesHash,
          dependencies: XdgSurfaceStatesFamily._dependencies,
          allTransitiveDependencies:
              XdgSurfaceStatesFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  XdgSurfaceStatesProvider._internal(
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
  XdgSurfaceState runNotifierBuild(
    covariant XdgSurfaceStates notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(XdgSurfaceStates Function() create) {
    return ProviderOverride(
      origin: this,
      override: XdgSurfaceStatesProvider._internal(
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
  NotifierProviderElement<XdgSurfaceStates, XdgSurfaceState> createElement() {
    return _XdgSurfaceStatesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is XdgSurfaceStatesProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin XdgSurfaceStatesRef on NotifierProviderRef<XdgSurfaceState> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _XdgSurfaceStatesProviderElement
    extends NotifierProviderElement<XdgSurfaceStates, XdgSurfaceState>
    with XdgSurfaceStatesRef {
  _XdgSurfaceStatesProviderElement(super.provider);

  @override
  int get viewId => (origin as XdgSurfaceStatesProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
