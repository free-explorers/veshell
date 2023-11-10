// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../../../../ui/mobile/virtual_keyboard/virtual_keyboard.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$keyboardIdHash() => r'9deabf278eff0c30dfc3ca1d3433975cefb57e38';

/// See also [keyboardId].
@ProviderFor(keyboardId)
final keyboardIdProvider = Provider<int>.internal(
  keyboardId,
  name: r'keyboardIdProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$keyboardIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef KeyboardIdRef = ProviderRef<int>;
String _$keyboardLayoutHash() => r'a67f59b4f35367845b59956d647f0a574cee44d6';

/// See also [KeyboardLayout].
@ProviderFor(KeyboardLayout)
final keyboardLayoutProvider =
    NotifierProvider<KeyboardLayout, KbLayout>.internal(
  KeyboardLayout.new,
  name: r'keyboardLayoutProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$keyboardLayoutHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$KeyboardLayout = Notifier<KbLayout>;
String _$keyboardLayerHash() => r'b14baeda507c5547d044d53d19efc960b7e7352a';

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

abstract class _$KeyboardLayer
    extends BuildlessAutoDisposeNotifier<KbLayerEnum> {
  late final int viewId;

  KbLayerEnum build(
    int viewId,
  );
}

/// See also [KeyboardLayer].
@ProviderFor(KeyboardLayer)
const keyboardLayerProvider = KeyboardLayerFamily();

/// See also [KeyboardLayer].
class KeyboardLayerFamily extends Family<KbLayerEnum> {
  /// See also [KeyboardLayer].
  const KeyboardLayerFamily();

  /// See also [KeyboardLayer].
  KeyboardLayerProvider call(
    int viewId,
  ) {
    return KeyboardLayerProvider(
      viewId,
    );
  }

  @override
  KeyboardLayerProvider getProviderOverride(
    covariant KeyboardLayerProvider provider,
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
  String? get name => r'keyboardLayerProvider';
}

/// See also [KeyboardLayer].
class KeyboardLayerProvider
    extends AutoDisposeNotifierProviderImpl<KeyboardLayer, KbLayerEnum> {
  /// See also [KeyboardLayer].
  KeyboardLayerProvider(
    int viewId,
  ) : this._internal(
          () => KeyboardLayer()..viewId = viewId,
          from: keyboardLayerProvider,
          name: r'keyboardLayerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$keyboardLayerHash,
          dependencies: KeyboardLayerFamily._dependencies,
          allTransitiveDependencies:
              KeyboardLayerFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  KeyboardLayerProvider._internal(
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
  KbLayerEnum runNotifierBuild(
    covariant KeyboardLayer notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(KeyboardLayer Function() create) {
    return ProviderOverride(
      origin: this,
      override: KeyboardLayerProvider._internal(
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
  AutoDisposeNotifierProviderElement<KeyboardLayer, KbLayerEnum>
      createElement() {
    return _KeyboardLayerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KeyboardLayerProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin KeyboardLayerRef on AutoDisposeNotifierProviderRef<KbLayerEnum> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _KeyboardLayerProviderElement
    extends AutoDisposeNotifierProviderElement<KeyboardLayer, KbLayerEnum>
    with KeyboardLayerRef {
  _KeyboardLayerProviderElement(super.provider);

  @override
  int get viewId => (origin as KeyboardLayerProvider).viewId;
}

String _$keyboardCaseHash() => r'393a7d3c147186e29e841bd2a90b460724e7da0b';

abstract class _$KeyboardCase extends BuildlessAutoDisposeNotifier<Case> {
  late final int viewId;

  Case build(
    int viewId,
  );
}

/// See also [KeyboardCase].
@ProviderFor(KeyboardCase)
const keyboardCaseProvider = KeyboardCaseFamily();

/// See also [KeyboardCase].
class KeyboardCaseFamily extends Family<Case> {
  /// See also [KeyboardCase].
  const KeyboardCaseFamily();

  /// See also [KeyboardCase].
  KeyboardCaseProvider call(
    int viewId,
  ) {
    return KeyboardCaseProvider(
      viewId,
    );
  }

  @override
  KeyboardCaseProvider getProviderOverride(
    covariant KeyboardCaseProvider provider,
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
  String? get name => r'keyboardCaseProvider';
}

/// See also [KeyboardCase].
class KeyboardCaseProvider
    extends AutoDisposeNotifierProviderImpl<KeyboardCase, Case> {
  /// See also [KeyboardCase].
  KeyboardCaseProvider(
    int viewId,
  ) : this._internal(
          () => KeyboardCase()..viewId = viewId,
          from: keyboardCaseProvider,
          name: r'keyboardCaseProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$keyboardCaseHash,
          dependencies: KeyboardCaseFamily._dependencies,
          allTransitiveDependencies:
              KeyboardCaseFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  KeyboardCaseProvider._internal(
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
  Case runNotifierBuild(
    covariant KeyboardCase notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(KeyboardCase Function() create) {
    return ProviderOverride(
      origin: this,
      override: KeyboardCaseProvider._internal(
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
  AutoDisposeNotifierProviderElement<KeyboardCase, Case> createElement() {
    return _KeyboardCaseProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KeyboardCaseProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin KeyboardCaseRef on AutoDisposeNotifierProviderRef<Case> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _KeyboardCaseProviderElement
    extends AutoDisposeNotifierProviderElement<KeyboardCase, Case>
    with KeyboardCaseRef {
  _KeyboardCaseProviderElement(super.provider);

  @override
  int get viewId => (origin as KeyboardCaseProvider).viewId;
}

String _$keyboardKeyWidthHash() => r'dff0fb730a1a44c86d543f492625d64dfe2a51ea';

abstract class _$KeyboardKeyWidth extends BuildlessNotifier<double> {
  late final int viewId;

  double build(
    int viewId,
  );
}

/// See also [KeyboardKeyWidth].
@ProviderFor(KeyboardKeyWidth)
const keyboardKeyWidthProvider = KeyboardKeyWidthFamily();

/// See also [KeyboardKeyWidth].
class KeyboardKeyWidthFamily extends Family<double> {
  /// See also [KeyboardKeyWidth].
  const KeyboardKeyWidthFamily();

  /// See also [KeyboardKeyWidth].
  KeyboardKeyWidthProvider call(
    int viewId,
  ) {
    return KeyboardKeyWidthProvider(
      viewId,
    );
  }

  @override
  KeyboardKeyWidthProvider getProviderOverride(
    covariant KeyboardKeyWidthProvider provider,
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
  String? get name => r'keyboardKeyWidthProvider';
}

/// See also [KeyboardKeyWidth].
class KeyboardKeyWidthProvider
    extends NotifierProviderImpl<KeyboardKeyWidth, double> {
  /// See also [KeyboardKeyWidth].
  KeyboardKeyWidthProvider(
    int viewId,
  ) : this._internal(
          () => KeyboardKeyWidth()..viewId = viewId,
          from: keyboardKeyWidthProvider,
          name: r'keyboardKeyWidthProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$keyboardKeyWidthHash,
          dependencies: KeyboardKeyWidthFamily._dependencies,
          allTransitiveDependencies:
              KeyboardKeyWidthFamily._allTransitiveDependencies,
          viewId: viewId,
        );

  KeyboardKeyWidthProvider._internal(
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
  double runNotifierBuild(
    covariant KeyboardKeyWidth notifier,
  ) {
    return notifier.build(
      viewId,
    );
  }

  @override
  Override overrideWith(KeyboardKeyWidth Function() create) {
    return ProviderOverride(
      origin: this,
      override: KeyboardKeyWidthProvider._internal(
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
  NotifierProviderElement<KeyboardKeyWidth, double> createElement() {
    return _KeyboardKeyWidthProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is KeyboardKeyWidthProvider && other.viewId == viewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, viewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin KeyboardKeyWidthRef on NotifierProviderRef<double> {
  /// The parameter `viewId` of this provider.
  int get viewId;
}

class _KeyboardKeyWidthProviderElement
    extends NotifierProviderElement<KeyboardKeyWidth, double>
    with KeyboardKeyWidthRef {
  _KeyboardKeyWidthProviderElement(super.provider);

  @override
  int get viewId => (origin as KeyboardKeyWidthProvider).viewId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
