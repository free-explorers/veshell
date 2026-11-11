import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';

part 'pid_to_meta_window_id.g.dart';

/// The live windows of a process, oldest first.
///
/// [MetaWindowState.create] adds a window and [MetaWindowState.destroy]
/// removes it, so a process with several windows still resolves to a live one
/// after its newest closes. A non-empty entry keeps itself alive; an emptied
/// one is released.
@riverpod
class PidToMetaWindowId extends _$PidToMetaWindowId {
  KeepAliveLink? _keepAliveLink;

  @override
  IList<MetaWindowId> build(int pid) => const IListConst([]);

  void add(MetaWindowId metaWindowId) {
    _keepAliveLink ??= ref.keepAlive();
    state = state.remove(metaWindowId).add(metaWindowId);
  }

  void remove(MetaWindowId metaWindowId) {
    state = state.remove(metaWindowId);
    if (state.isEmpty) {
      _keepAliveLink?.close();
      _keepAliveLink = null;
    }
  }
}

/// Access to [PidToMetaWindowId] for keepAlive providers.
///
/// riverpod_lint flags keepAlive providers that use auto-dispose ones, but it
/// cannot see a `ref.keepAlive()` link taken by hand. An entry pins itself
/// with one while its process has a live window, so reading it from a
/// keepAlive provider is safe.
/// Only add accessors here for that reason: route anything else through
/// `ref` so the lint keeps checking it.
extension PidToMetaWindowIdAccess on Ref {
  /// The newest live window of [pid], or `null` when it has none.
  MetaWindowId? readMetaWindowIdForPid(int pid) =>
      read(pidToMetaWindowIdProvider(pid)).lastOrNull;
}
