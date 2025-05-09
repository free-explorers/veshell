import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';

part 'meta_window_children.g.dart';

@riverpod
class MetaWindowChildren extends _$MetaWindowChildren {
  KeepAliveLink? _keepAliveLink;
  @override
  ISet<MetaWindowId> build(MetaWindowId parentId) {
    return ISet();
  }

  void add(MetaWindowId childId) {
    _keepAliveLink ??= ref.keepAlive();
    state = state.add(childId);
  }

  void remove(MetaWindowId childId) {
    state = state.remove(childId);
    if (state.isEmpty) {
      _keepAliveLink?.close();
      _keepAliveLink = null;
    }
  }
}
