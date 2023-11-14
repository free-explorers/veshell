// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/desktop/state/window_position_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$windowPositionHash() => r'ee0468ead9f838ee4c110cd70a4630bfc38680a5';

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

abstract class _$WindowPosition extends BuildlessNotifier<Offset> {
  late final int viewId;

  Offset build(
    int viewId,
  );
}

/// See also [WindowPosition].
@ProviderFor(WindowPosition)
const windowPositionProvider = WindowPositionFamily();

/// See also [WindowPosition].
class WindowPositionFamily extends Family<Offset> {
  /// See also [WindowPosition].
  const WindowPositionFamily();

  /// See also [WindowPosition].
  WindowPositionProvider call(
    int viewId,
  ) {
    return WindowPositionProvider(
      viewId,
    );
  }

  @override
  WindowPositionProvider getProviderOverride(
    covariant WindowPositionProvider provider,
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
  String? get name => r'windowPositionProvider';
}

/// See also [WindowPosition].
class WindowPositionProvider
    extends NotifierProviderImpl<WindowPosition, Offset> {
  /// See also [WindowPosition].
  WindowPositionProvider(
    int viewId,
  ) : this._internal(
          () => WindowPosition()..viewId = viewId,
          from: windowPositionProvider,
          name: r'windowPositionProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$windowPositionHash,
          dependencies: WindowPositionFamily._dependencies,
          allTransitiveDependencies:
              WindowPositionFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  WindowPositionProvider._internal(
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
  Offset runNotifierBuild(
    covariant WindowPosition notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(WindowPosition Function() create) {
    return ProviderOverride(
      origin: this,
      override: WindowPositionProvider._internal(
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
  NotifierProviderElement<WindowPosition, Offset> createElement() {
    return _WindowPositionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WindowPositionProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin WindowPositionRef on NotifierProviderRef<Offset> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _WindowPositionProviderElement
    extends NotifierProviderElement<WindowPosition, Offset>
    with WindowPositionRef {
  _WindowPositionProviderElement(super.provider);

  @override
  int get viewId => (origin as WindowPositionProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
