// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hotkeys_activator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HotkeysActivator)
const hotkeysActivatorProvider = HotkeysActivatorProvider._();

final class HotkeysActivatorProvider
    extends
        $NotifierProvider<HotkeysActivator, Map<ShortcutActivator, Intent>> {
  const HotkeysActivatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hotkeysActivatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hotkeysActivatorHash();

  @$internal
  @override
  HotkeysActivator create() => HotkeysActivator();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<ShortcutActivator, Intent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<ShortcutActivator, Intent>>(
        value,
      ),
    );
  }
}

String _$hotkeysActivatorHash() => r'5e9faa6d732d5704b51da7d972314a71d89b62ee';

abstract class _$HotkeysActivator
    extends $Notifier<Map<ShortcutActivator, Intent>> {
  Map<ShortcutActivator, Intent> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              Map<ShortcutActivator, Intent>,
              Map<ShortcutActivator, Intent>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<ShortcutActivator, Intent>,
                Map<ShortcutActivator, Intent>
              >,
              Map<ShortcutActivator, Intent>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
