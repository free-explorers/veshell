// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/common/state/xdg_surface_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$xdgSurfaceStatesHash() => r'604f2bfdfc7819f81145941643b4b99e59c72c65';

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
    this.viewId,
  ) : super.internal(
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
        );

  final int viewId;

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

  @override
  XdgSurfaceState runNotifierBuild(
    covariant XdgSurfaceStates notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }
}
// ignore_for_file: unnecessary_raw_strings, subtype_of_sealed_class, invalid_use_of_internal_member, do_not_use_environment, prefer_const_constructors, public_member_api_docs, avoid_private_typedef_functions
