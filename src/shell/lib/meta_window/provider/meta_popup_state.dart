import 'package:hooks_riverpod/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_popup.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_for_id.dart';
import 'package:shell/platform/model/event/meta_popup_created/meta_popup_created.serializable.dart';
import 'package:shell/platform/model/event/meta_popup_patches/meta_popup_patches.serializable.dart';
import 'package:shell/platform/model/request/meta_popup_patches/meta_popup_patches.dart';
import 'package:shell/platform/provider/platform_manager.dart';

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
      position: message.position,
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
          .request(
            MetaPopupPatchesRequest(
              message: patch,
            ),
          );
    }
  }

  void destroy() {
    _keepAliveLink?.close();
    ref.read(metaPopupForIdProvider(state.parent).notifier).remove(id);
  }
}
