// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pointer_focus.manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The problem:
/// When moving the pointer between 2 MouseRegions, one would trigger an exit event, and the other one an enter event.
/// Let's suppose we have a window and a popup. The pointer exits the window surface and enters the popup surface.
/// When the pointer exits the window surface, this event is propagated to the window and it happens to decide to close
/// the popup even though we moved the pointer on the popup.
///
/// The solution:
/// Don't send the exit event right away. See if an enter event is generated just after.
/// We schedule a asynchronous task for sending an exit event, but if an enter event happens before the next event loop
/// iteration, we cancel the currently scheduled task, thus the exit event will no longer be sent.

@ProviderFor(PointerFocusManager)
const pointerFocusManagerProvider = PointerFocusManagerProvider._();

/// The problem:
/// When moving the pointer between 2 MouseRegions, one would trigger an exit event, and the other one an enter event.
/// Let's suppose we have a window and a popup. The pointer exits the window surface and enters the popup surface.
/// When the pointer exits the window surface, this event is propagated to the window and it happens to decide to close
/// the popup even though we moved the pointer on the popup.
///
/// The solution:
/// Don't send the exit event right away. See if an enter event is generated just after.
/// We schedule a asynchronous task for sending an exit event, but if an enter event happens before the next event loop
/// iteration, we cancel the currently scheduled task, thus the exit event will no longer be sent.
final class PointerFocusManagerProvider
    extends $NotifierProvider<PointerFocusManager, PointerFocus?> {
  /// The problem:
  /// When moving the pointer between 2 MouseRegions, one would trigger an exit event, and the other one an enter event.
  /// Let's suppose we have a window and a popup. The pointer exits the window surface and enters the popup surface.
  /// When the pointer exits the window surface, this event is propagated to the window and it happens to decide to close
  /// the popup even though we moved the pointer on the popup.
  ///
  /// The solution:
  /// Don't send the exit event right away. See if an enter event is generated just after.
  /// We schedule a asynchronous task for sending an exit event, but if an enter event happens before the next event loop
  /// iteration, we cancel the currently scheduled task, thus the exit event will no longer be sent.
  const PointerFocusManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pointerFocusManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pointerFocusManagerHash();

  @$internal
  @override
  PointerFocusManager create() => PointerFocusManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PointerFocus? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PointerFocus?>(value),
    );
  }
}

String _$pointerFocusManagerHash() =>
    r'b83a7f0e87acb8515dabc6cf0afb89720c3edbe1';

/// The problem:
/// When moving the pointer between 2 MouseRegions, one would trigger an exit event, and the other one an enter event.
/// Let's suppose we have a window and a popup. The pointer exits the window surface and enters the popup surface.
/// When the pointer exits the window surface, this event is propagated to the window and it happens to decide to close
/// the popup even though we moved the pointer on the popup.
///
/// The solution:
/// Don't send the exit event right away. See if an enter event is generated just after.
/// We schedule a asynchronous task for sending an exit event, but if an enter event happens before the next event loop
/// iteration, we cancel the currently scheduled task, thus the exit event will no longer be sent.

abstract class _$PointerFocusManager extends $Notifier<PointerFocus?> {
  PointerFocus? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PointerFocus?, PointerFocus?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PointerFocus?, PointerFocus?>,
              PointerFocus?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
