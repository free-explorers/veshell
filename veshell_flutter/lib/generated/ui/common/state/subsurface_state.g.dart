// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/common/state/subsurface_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$subsurfaceWidgetHash() => r'fcd7a64b6357acdd2c0adac0c831371b72de08fd';

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

/// See also [subsurfaceWidget].
@ProviderFor(subsurfaceWidget)
const subsurfaceWidgetProvider = SubsurfaceWidgetFamily();

/// See also [subsurfaceWidget].
class SubsurfaceWidgetFamily extends Family<Subsurface> {
  /// See also [subsurfaceWidget].
  const SubsurfaceWidgetFamily();

  /// See also [subsurfaceWidget].
  SubsurfaceWidgetProvider call(
    int viewId,
  ) {
    return SubsurfaceWidgetProvider(
      viewId,
    );
  }

  @override
  SubsurfaceWidgetProvider getProviderOverride(
    covariant SubsurfaceWidgetProvider provider,
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
  String? get name => r'subsurfaceWidgetProvider';
}

/// See also [subsurfaceWidget].
class SubsurfaceWidgetProvider extends Provider<Subsurface> {
  /// See also [subsurfaceWidget].
  SubsurfaceWidgetProvider(
    int viewId,
  ) : this._internal(
          (ref) => subsurfaceWidget(
            ref as SubsurfaceWidgetRef,
            viewId,
          ),
          from: subsurfaceWidgetProvider,
          name: r'subsurfaceWidgetProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$subsurfaceWidgetHash,
          dependencies: SubsurfaceWidgetFamily._dependencies,
          allTransitiveDependencies:
              SubsurfaceWidgetFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  SubsurfaceWidgetProvider._internal(
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
    Subsurface Function(SubsurfaceWidgetRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SubsurfaceWidgetProvider._internal(
        (ref) => create(ref as SubsurfaceWidgetRef),
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
  ProviderElement<Subsurface> createElement() {
    return _SubsurfaceWidgetProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SubsurfaceWidgetProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SubsurfaceWidgetRef on ProviderRef<Subsurface> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _SubsurfaceWidgetProviderElement extends ProviderElement<Subsurface>
    with SubsurfaceWidgetRef {
  _SubsurfaceWidgetProviderElement(super.provider);

  @override
  int get viewId => (origin as SubsurfaceWidgetProvider).viewId;
}

String _$subsurfaceStatesHash() => r'30e609cd91a810f3477db020d3264d91d4d50686';

abstract class _$SubsurfaceStates extends BuildlessNotifier<SubsurfaceState> {
  late final int viewId;

  SubsurfaceState build(
    int viewId,
  );
}

/// See also [SubsurfaceStates].
@ProviderFor(SubsurfaceStates)
const subsurfaceStatesProvider = SubsurfaceStatesFamily();

/// See also [SubsurfaceStates].
class SubsurfaceStatesFamily extends Family<SubsurfaceState> {
  /// See also [SubsurfaceStates].
  const SubsurfaceStatesFamily();

  /// See also [SubsurfaceStates].
  SubsurfaceStatesProvider call(
    int viewId,
  ) {
    return SubsurfaceStatesProvider(
      viewId,
    );
  }

  @override
  SubsurfaceStatesProvider getProviderOverride(
    covariant SubsurfaceStatesProvider provider,
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
  String? get name => r'subsurfaceStatesProvider';
}

/// See also [SubsurfaceStates].
class SubsurfaceStatesProvider
    extends NotifierProviderImpl<SubsurfaceStates, SubsurfaceState> {
  /// See also [SubsurfaceStates].
  SubsurfaceStatesProvider(
    int viewId,
  ) : this._internal(
          () => SubsurfaceStates()..viewId = viewId,
          from: subsurfaceStatesProvider,
          name: r'subsurfaceStatesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$subsurfaceStatesHash,
          dependencies: SubsurfaceStatesFamily._dependencies,
          allTransitiveDependencies:
              SubsurfaceStatesFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  SubsurfaceStatesProvider._internal(
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
  SubsurfaceState runNotifierBuild(
    covariant SubsurfaceStates notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(SubsurfaceStates Function() create) {
    return ProviderOverride(
      origin: this,
      override: SubsurfaceStatesProvider._internal(
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
  NotifierProviderElement<SubsurfaceStates, SubsurfaceState> createElement() {
    return _SubsurfaceStatesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SubsurfaceStatesProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SubsurfaceStatesRef on NotifierProviderRef<SubsurfaceState> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _SubsurfaceStatesProviderElement
    extends NotifierProviderElement<SubsurfaceStates, SubsurfaceState>
    with SubsurfaceStatesRef {
  _SubsurfaceStatesProviderElement(super.provider);

  @override
  int get viewId => (origin as SubsurfaceStatesProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
