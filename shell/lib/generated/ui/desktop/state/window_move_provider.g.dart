// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/desktop/state/window_move_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$windowMoveHash() => r'906b622cca6393b80fd2e9b10cd366e28bf02cd6';

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

abstract class _$WindowMove extends BuildlessNotifier<WindowMoveState> {
  late final int viewId;

  WindowMoveState build(
    int viewId,
  );
}

/// See also [WindowMove].
@ProviderFor(WindowMove)
const windowMoveProvider = WindowMoveFamily();

/// See also [WindowMove].
class WindowMoveFamily extends Family<WindowMoveState> {
  /// See also [WindowMove].
  const WindowMoveFamily();

  /// See also [WindowMove].
  WindowMoveProvider call(
    int viewId,
  ) {
    return WindowMoveProvider(
      viewId,
    );
  }

  @override
  WindowMoveProvider getProviderOverride(
    covariant WindowMoveProvider provider,
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
  String? get name => r'windowMoveProvider';
}

/// See also [WindowMove].
class WindowMoveProvider
    extends NotifierProviderImpl<WindowMove, WindowMoveState> {
  /// See also [WindowMove].
  WindowMoveProvider(
    int viewId,
  ) : this._internal(
          () => WindowMove()..viewId = viewId,
          from: windowMoveProvider,
          name: r'windowMoveProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$windowMoveHash,
          dependencies: WindowMoveFamily._dependencies,
          allTransitiveDependencies:
              WindowMoveFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  WindowMoveProvider._internal(
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
  WindowMoveState runNotifierBuild(
    covariant WindowMove notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(WindowMove Function() create) {
    return ProviderOverride(
      origin: this,
      override: WindowMoveProvider._internal(
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
  NotifierProviderElement<WindowMove, WindowMoveState> createElement() {
    return _WindowMoveProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WindowMoveProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WindowMoveRef on NotifierProviderRef<WindowMoveState> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _WindowMoveProviderElement
    extends NotifierProviderElement<WindowMove, WindowMoveState>
    with WindowMoveRef {
  _WindowMoveProviderElement(super.provider);

  @override
  int get viewId => (origin as WindowMoveProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
