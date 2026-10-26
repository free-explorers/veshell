import 'dart:async';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_popup.serializable.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_for_id.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/platform/model/event/meta_popup_created/meta_popup_created.serializable.dart';
import 'package:shell/platform/model/event/meta_popup_patches/meta_popup_patches.serializable.dart';
import 'package:shell/platform/model/request/meta_popup_patches/meta_popup_patches.dart';
import 'package:shell/platform/model/request/mouse_buttons_event/mouse_buttons_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/pointer/model/pointer_focus.serializable.dart';
import 'package:shell/pointer/provider/pointer_focus.manager.dart';
import 'package:shell/shared/provider/mouse_button_tracker.dart';

part 'meta_popup_state.g.dart';

@riverpod
class MetaPopupState extends _$MetaPopupState {
  KeepAliveLink? _keepAliveLink;

  @override
  MetaPopup build(String id) {
    throw Exception('MetaPopupState $id not yet initialized');
  }

  void create(MetaPopupCreatedMessage message) {
    _keepAliveLink?.close();
    _keepAliveLink = ref.keepAlive();

    state = MetaPopup(
      id: id,
      parent: message.parent,
      category: message.category,
      position: message.position,
      geometry: message.geometry,
      surfaceId: message.surfaceId,
      scaleRatio: message.scaleRatio,
    );

    ref.read(metaPopupForIdProvider(state.parent).notifier).add(id);
  }

  Future<void> patch(
    MetaPopupPatchMessage patch, {
    bool propagate = true,
  }) async {
    switch (patch) {
      case UpdatePosition():
        state = state.copyWith(position: patch.value);
      case UpdateScaleRatio():
        state = state.copyWith(scaleRatio: patch.value);
      case UpdateGeometry():
        state = state.copyWith(geometry: patch.value);
    }

    if (propagate == true) {
      await ref
          .read(platformManagerProvider.notifier)
          .request(MetaPopupPatchesRequest(message: patch));
    }
  }

  void destroy() {
    // Flutter is the focus master. If this popup is focused when its surface
    // is removed, restore focus to the owner's current *rendered* origin.
    // Never fall back to the native X11 root: in non-floating modes that root
    // is a synthetic (0,0) value.
    final popupSurfaceId = state.surfaceId;
    final parentId = state.parent;
    final focusManager = ref.read(pointerFocusManagerProvider.notifier);
    // Teardown is global only for the popup that currently owns pointer focus.
    // An unrelated popup closing must not reset another surface's drag or
    // flush the compositor-wide button tracker.
    if (focusManager.currentFocus?.surfaceId != popupSurfaceId) {
      focusManager.forgetSurface(popupSurfaceId);
    } else {
      try {
        final parent = ref.read(metaWindowStateProvider(parentId));
        // Restore to the owner's surface origin. Popup placement is tile
        // relative, so subtracting it from the popup's global focus offset
        // cannot recover the parent origin without a second coordinate anchor.
        // The parent model already owns the authoritative origin for its mode.
        final origin =
            parent.floatingSurfaceOrigin ??
            parent.renderOrigin ??
            ref.read(surfaceRenderOriginsProvider)[parent.surfaceId];
        // The popup may have consumed the primary button-up when it closed.
        // Flutter's button bitmap would then stay latched, making the next
        // primary press look like a release and blocking hover. Flush any stuck
        // buttons to the owner before restoring focus.
        final releases = ref
            .read(mouseButtonTrackerProvider)
            .trackButtonState(0);
        focusManager.resetDrag();
        if (origin != null) {
          focusManager.restoreSurface(
            popupSurfaceId,
            PointerFocus(surfaceId: parent.surfaceId, globalOffset: origin),
          );
        } else {
          focusManager.forgetSurface(popupSurfaceId);
        }
        if (releases.isNotEmpty) {
          unawaited(
            ref
                .read(platformManagerProvider.notifier)
                .request(
                  MouseButtonsEventRequest(
                    message: MouseButtonsEventMessage(
                      surfaceId: parent.surfaceId,
                      buttons: [
                        for (final event in releases)
                          Button(
                            button: event.button,
                            isPressed: event.state == MouseButtonState.pressed,
                          ),
                      ].lockUnsafe,
                    ),
                  ),
                ),
          );
        }
      } on Object {
        // The owner may already be torn down; clearing the local focus is the
        // only safe fallback.
        focusManager.forgetSurface(popupSurfaceId);
      }
    }
    _keepAliveLink?.close();
    ref.read(metaPopupForIdProvider(state.parent).notifier).remove(id);
  }
}
