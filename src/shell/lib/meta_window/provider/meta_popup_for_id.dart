import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_popup.serializable.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';

part 'meta_popup_for_id.g.dart';

@riverpod
class MetaPopupForId extends _$MetaPopupForId {
  KeepAliveLink? _keepAliveLink;
  @override
  ISet<MetaPopupId> build(MetaWindowId parentId) {
    return ISet();
  }

  void add(MetaPopupId popupId) {
    _keepAliveLink ??= ref.keepAlive();
    state = state.add(popupId);
  }

  void remove(MetaPopupId popupId) {
    state = state.remove(popupId);
    if (state.isEmpty) {
      _keepAliveLink?.close();
      _keepAliveLink = null;
    }
  }
}
