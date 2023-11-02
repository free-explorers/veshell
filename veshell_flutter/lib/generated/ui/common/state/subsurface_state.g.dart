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

typedef SubsurfaceWidgetRef = ProviderRef<Subsurface>;

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
    this.viewId,
  ) : super.internal(
          (ref) => subsurfaceWidget(
            ref,
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
        );

  final int viewId;

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

String _$subsurfaceStatesHash() => r'4f9acc62d958c409876790f543760795dd38c5dd';

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
    this.viewId,
  ) : super.internal(
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
        );

  final int viewId;

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

  @override
  SubsurfaceState runNotifierBuild(
    covariant SubsurfaceStates notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }
}
// ignore_for_file: unnecessary_raw_strings, subtype_of_sealed_class, invalid_use_of_internal_member, do_not_use_environment, prefer_const_constructors, public_member_api_docs, avoid_private_typedef_functions
