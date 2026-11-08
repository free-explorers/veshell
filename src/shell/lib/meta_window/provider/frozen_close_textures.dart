import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';

part 'frozen_close_textures.g.dart';

/// How long the compositor keeps a frozen frame the shell has not released
/// (`RETAINED_TEXTURE_LIFETIME`): past it, the texture id means nothing.
const _frozenTextureLifetime = Duration(seconds: 5);

/// The frame each window painted when the shell asked it to close, as the
/// compositor copied it: an external texture of its own, which nothing the
/// client paints afterwards can reach (see `close_window`).
///
/// The closing animation [take]s it once the window is gone, and releases it
/// when it ends.
///
/// A plain store rather than watched state: it is taken while the tile
/// builds, where a provider's state must not change.
@Riverpod(keepAlive: true)
class FrozenCloseTextures extends _$FrozenCloseTextures {
  final _textures = <MetaWindowId, int>{};
  final _expiries = <MetaWindowId, Timer>{};

  @override
  void build() {
    ref.onDispose(() {
      for (final timer in _expiries.values) {
        timer.cancel();
      }
    });
  }

  void put(MetaWindowId metaWindowId, int textureId) {
    _expiries.remove(metaWindowId)?.cancel();
    _expiries[metaWindowId] = Timer(_frozenTextureLifetime, () {
      _expiries.remove(metaWindowId);
      _textures.remove(metaWindowId);
    });
    _textures[metaWindowId] = textureId;
  }

  /// The frozen frame of [metaWindowId], forgotten here once taken.
  int? take(MetaWindowId metaWindowId) {
    _expiries.remove(metaWindowId)?.cancel();
    return _textures.remove(metaWindowId);
  }
}
