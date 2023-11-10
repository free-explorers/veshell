// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/common/state/xdg_toplevel_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$xdgToplevelSurfaceWidgetHash() =>
    r'ce954f185d200a85580d64d50482c72176a291a4';

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

/// See also [xdgToplevelSurfaceWidget].
@ProviderFor(xdgToplevelSurfaceWidget)
const xdgToplevelSurfaceWidgetProvider = XdgToplevelSurfaceWidgetFamily();

/// See also [xdgToplevelSurfaceWidget].
class XdgToplevelSurfaceWidgetFamily extends Family<XdgToplevelSurface> {
  /// See also [xdgToplevelSurfaceWidget].
  const XdgToplevelSurfaceWidgetFamily();

  /// See also [xdgToplevelSurfaceWidget].
  XdgToplevelSurfaceWidgetProvider call(
    int viewId,
  ) {
    return XdgToplevelSurfaceWidgetProvider(
      viewId,
    );
  }

  @override
  XdgToplevelSurfaceWidgetProvider getProviderOverride(
    covariant XdgToplevelSurfaceWidgetProvider provider,
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
  String? get name => r'xdgToplevelSurfaceWidgetProvider';
}

/// See also [xdgToplevelSurfaceWidget].
class XdgToplevelSurfaceWidgetProvider extends Provider<XdgToplevelSurface> {
  /// See also [xdgToplevelSurfaceWidget].
  XdgToplevelSurfaceWidgetProvider(
    int viewId,
  ) : this._internal(
          (ref) => xdgToplevelSurfaceWidget(
            ref as XdgToplevelSurfaceWidgetRef,
            viewId,
          ),
          from: xdgToplevelSurfaceWidgetProvider,
          name: r'xdgToplevelSurfaceWidgetProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$xdgToplevelSurfaceWidgetHash,
          dependencies: XdgToplevelSurfaceWidgetFamily._dependencies,
          allTransitiveDependencies:
              XdgToplevelSurfaceWidgetFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  XdgToplevelSurfaceWidgetProvider._internal(
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
    XdgToplevelSurface Function(XdgToplevelSurfaceWidgetRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: XdgToplevelSurfaceWidgetProvider._internal(
        (ref) => create(ref as XdgToplevelSurfaceWidgetRef),
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
  ProviderElement<XdgToplevelSurface> createElement() {
    return _XdgToplevelSurfaceWidgetProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is XdgToplevelSurfaceWidgetProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin XdgToplevelSurfaceWidgetRef on ProviderRef<XdgToplevelSurface> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _XdgToplevelSurfaceWidgetProviderElement
    extends ProviderElement<XdgToplevelSurface>
    with XdgToplevelSurfaceWidgetRef {
  _XdgToplevelSurfaceWidgetProviderElement(super.provider);

  @override
  int get viewId => (origin as XdgToplevelSurfaceWidgetProvider).viewId;
}

String _$xdgToplevelStatesHash() => r'df3d83b090758345e241bc50c1d90347227dd84b';

abstract class _$XdgToplevelStates extends BuildlessNotifier<XdgToplevelState> {
  late final int viewId;

  XdgToplevelState build(
    int viewId,
  );
}

/// See also [XdgToplevelStates].
@ProviderFor(XdgToplevelStates)
const xdgToplevelStatesProvider = XdgToplevelStatesFamily();

/// See also [XdgToplevelStates].
class XdgToplevelStatesFamily extends Family<XdgToplevelState> {
  /// See also [XdgToplevelStates].
  const XdgToplevelStatesFamily();

  /// See also [XdgToplevelStates].
  XdgToplevelStatesProvider call(
    int viewId,
  ) {
    return XdgToplevelStatesProvider(
      viewId,
    );
  }

  @override
  XdgToplevelStatesProvider getProviderOverride(
    covariant XdgToplevelStatesProvider provider,
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
  String? get name => r'xdgToplevelStatesProvider';
}

/// See also [XdgToplevelStates].
class XdgToplevelStatesProvider
    extends NotifierProviderImpl<XdgToplevelStates, XdgToplevelState> {
  /// See also [XdgToplevelStates].
  XdgToplevelStatesProvider(
    int viewId,
  ) : this._internal(
          () => XdgToplevelStates()..viewId = viewId,
          from: xdgToplevelStatesProvider,
          name: r'xdgToplevelStatesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$xdgToplevelStatesHash,
          dependencies: XdgToplevelStatesFamily._dependencies,
          allTransitiveDependencies:
              XdgToplevelStatesFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  XdgToplevelStatesProvider._internal(
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
  XdgToplevelState runNotifierBuild(
    covariant XdgToplevelStates notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(XdgToplevelStates Function() create) {
    return ProviderOverride(
      origin: this,
      override: XdgToplevelStatesProvider._internal(
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
  NotifierProviderElement<XdgToplevelStates, XdgToplevelState> createElement() {
    return _XdgToplevelStatesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is XdgToplevelStatesProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin XdgToplevelStatesRef on NotifierProviderRef<XdgToplevelState> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _XdgToplevelStatesProviderElement
    extends NotifierProviderElement<XdgToplevelStates, XdgToplevelState>
    with XdgToplevelStatesRef {
  _XdgToplevelStatesProviderElement(super.provider);

  @override
  int get viewId => (origin as XdgToplevelStatesProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
