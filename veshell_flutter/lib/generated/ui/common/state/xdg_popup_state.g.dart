// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/common/state/xdg_popup_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$popupWidgetHash() => r'1f9f6bb7904d7e08286d908e4dfe11bf068155de';

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

/// See also [popupWidget].
@ProviderFor(popupWidget)
const popupWidgetProvider = PopupWidgetFamily();

/// See also [popupWidget].
class PopupWidgetFamily extends Family<Popup> {
  /// See also [popupWidget].
  const PopupWidgetFamily();

  /// See also [popupWidget].
  PopupWidgetProvider call(
    int viewId,
  ) {
    return PopupWidgetProvider(
      viewId,
    );
  }

  @override
  PopupWidgetProvider getProviderOverride(
    covariant PopupWidgetProvider provider,
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
  String? get name => r'popupWidgetProvider';
}

/// See also [popupWidget].
class PopupWidgetProvider extends Provider<Popup> {
  /// See also [popupWidget].
  PopupWidgetProvider(
    int viewId,
  ) : this._internal(
          (ref) => popupWidget(
            ref as PopupWidgetRef,
            viewId,
          ),
          from: popupWidgetProvider,
          name: r'popupWidgetProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$popupWidgetHash,
          dependencies: PopupWidgetFamily._dependencies,
          allTransitiveDependencies:
              PopupWidgetFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  PopupWidgetProvider._internal(
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
    Popup Function(PopupWidgetRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PopupWidgetProvider._internal(
        (ref) => create(ref as PopupWidgetRef),
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
  ProviderElement<Popup> createElement() {
    return _PopupWidgetProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PopupWidgetProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin PopupWidgetRef on ProviderRef<Popup> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _PopupWidgetProviderElement extends ProviderElement<Popup>
    with PopupWidgetRef {
  _PopupWidgetProviderElement(super.provider);

  @override
  int get viewId => (origin as PopupWidgetProvider).viewId;
}

String _$xdgPopupStatesHash() => r'21bc9d8c0b8e062e6c78cffe58f2d68182aad623';

abstract class _$XdgPopupStates extends BuildlessNotifier<XdgPopupState> {
  late final int viewId;

  XdgPopupState build(
    int viewId,
  );
}

/// See also [XdgPopupStates].
@ProviderFor(XdgPopupStates)
const xdgPopupStatesProvider = XdgPopupStatesFamily();

/// See also [XdgPopupStates].
class XdgPopupStatesFamily extends Family<XdgPopupState> {
  /// See also [XdgPopupStates].
  const XdgPopupStatesFamily();

  /// See also [XdgPopupStates].
  XdgPopupStatesProvider call(
    int viewId,
  ) {
    return XdgPopupStatesProvider(
      viewId,
    );
  }

  @override
  XdgPopupStatesProvider getProviderOverride(
    covariant XdgPopupStatesProvider provider,
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
  String? get name => r'xdgPopupStatesProvider';
}

/// See also [XdgPopupStates].
class XdgPopupStatesProvider
    extends NotifierProviderImpl<XdgPopupStates, XdgPopupState> {
  /// See also [XdgPopupStates].
  XdgPopupStatesProvider(
    int viewId,
  ) : this._internal(
          () => XdgPopupStates()..viewId = viewId,
          from: xdgPopupStatesProvider,
          name: r'xdgPopupStatesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$xdgPopupStatesHash,
          dependencies: XdgPopupStatesFamily._dependencies,
          allTransitiveDependencies:
              XdgPopupStatesFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  XdgPopupStatesProvider._internal(
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
  XdgPopupState runNotifierBuild(
    covariant XdgPopupStates notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(XdgPopupStates Function() create) {
    return ProviderOverride(
      origin: this,
      override: XdgPopupStatesProvider._internal(
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
  NotifierProviderElement<XdgPopupStates, XdgPopupState> createElement() {
    return _XdgPopupStatesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is XdgPopupStatesProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin XdgPopupStatesRef on NotifierProviderRef<XdgPopupState> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _XdgPopupStatesProviderElement
    extends NotifierProviderElement<XdgPopupStates, XdgPopupState>
    with XdgPopupStatesRef {
  _XdgPopupStatesProviderElement(super.provider);

  @override
  int get viewId => (origin as XdgPopupStatesProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
