// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../ui/desktop/window.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$windowWidgetHash() => r'a09526c13b4ec9f244327865885215f73e5a19a7';

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

/// See also [windowWidget].
@ProviderFor(windowWidget)
const windowWidgetProvider = WindowWidgetFamily();

/// See also [windowWidget].
class WindowWidgetFamily extends Family<Window> {
  /// See also [windowWidget].
  const WindowWidgetFamily();

  /// See also [windowWidget].
  WindowWidgetProvider call(
    int viewId,
  ) {
    return WindowWidgetProvider(
      viewId,
    );
  }

  @override
  WindowWidgetProvider getProviderOverride(
    covariant WindowWidgetProvider provider,
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
  String? get name => r'windowWidgetProvider';
}

/// See also [windowWidget].
class WindowWidgetProvider extends Provider<Window> {
  /// See also [windowWidget].
  WindowWidgetProvider(
    int viewId,
  ) : this._internal(
          (ref) => windowWidget(
            ref as WindowWidgetRef,
            viewId,
          ),
          from: windowWidgetProvider,
          name: r'windowWidgetProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$windowWidgetHash,
          dependencies: WindowWidgetFamily._dependencies,
          allTransitiveDependencies:
              WindowWidgetFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  WindowWidgetProvider._internal(
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
    Window Function(WindowWidgetRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WindowWidgetProvider._internal(
        (ref) => create(ref as WindowWidgetRef),
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
  ProviderElement<Window> createElement() {
    return _WindowWidgetProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WindowWidgetProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WindowWidgetRef on ProviderRef<Window> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _WindowWidgetProviderElement extends ProviderElement<Window>
    with WindowWidgetRef {
  _WindowWidgetProviderElement(super.provider);

  @override
  int get viewId => (origin as WindowWidgetProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
