// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/desktop/state/window_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$windowStateHash() => r'385539b0f91dc3e85fc66c834b5e5c399b64ff5b';

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

abstract class _$WindowState extends BuildlessNotifier<WindowProviderState> {
  late final int viewId;

  WindowProviderState build(
    int viewId,
  );
}

/// See also [WindowState].
@ProviderFor(WindowState)
const windowStateProvider = WindowStateFamily();

/// See also [WindowState].
class WindowStateFamily extends Family<WindowProviderState> {
  /// See also [WindowState].
  const WindowStateFamily();

  /// See also [WindowState].
  WindowStateProvider call(
    int viewId,
  ) {
    return WindowStateProvider(
      viewId,
    );
  }

  @override
  WindowStateProvider getProviderOverride(
    covariant WindowStateProvider provider,
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
  String? get name => r'windowStateProvider';
}

/// See also [WindowState].
class WindowStateProvider
    extends NotifierProviderImpl<WindowState, WindowProviderState> {
  /// See also [WindowState].
  WindowStateProvider(
    int viewId,
  ) : this._internal(
          () => WindowState()..viewId = viewId,
          from: windowStateProvider,
          name: r'windowStateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$windowStateHash,
          dependencies: WindowStateFamily._dependencies,
          allTransitiveDependencies:
              WindowStateFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  WindowStateProvider._internal(
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
  WindowProviderState runNotifierBuild(
    covariant WindowState notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(WindowState Function() create) {
    return ProviderOverride(
      origin: this,
      override: WindowStateProvider._internal(
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
  NotifierProviderElement<WindowState, WindowProviderState> createElement() {
    return _WindowStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WindowStateProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WindowStateRef on NotifierProviderRef<WindowProviderState> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _WindowStateProviderElement
    extends NotifierProviderElement<WindowState, WindowProviderState>
    with WindowStateRef {
  _WindowStateProviderElement(super.provider);

  @override
  int get viewId => (origin as WindowStateProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
