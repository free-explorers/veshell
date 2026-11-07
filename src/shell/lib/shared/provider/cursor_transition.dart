import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cursor_transition.g.dart';

/// How long the cursor stays held after the last slide settles.
///
/// The settled layout reports its own cursor in a following frame; holding for
/// slightly longer lets that report replace the arrow a leaving page reported
/// during the animation.
const _settleDelay = Duration(milliseconds: 100);

/// Holds the shell's cursor shape while tile rows and workspaces slide.
///
/// A page leaving the hit test reports the default arrow even though it is
/// still painted under a stationary pointer. Applying that report would blink
/// the cursor on every `Super` navigation, so the embedder keeps showing the
/// shape it had and applies the last reported shape once the slide settles.
///
/// The short settle delay lets the settled layout report its own cursor
/// first: that report is the one that must win, not the arrow a leaving page
/// reported during the animation.
@Riverpod(keepAlive: true)
class CursorTransition extends _$CursorTransition {
  final _active = <Object>{};
  Timer? _settle;
  bool _transitioning = false;

  @override
  bool build() => false;

  /// Marks [token] as sliding.
  void begin(Object token) {
    _settle?.cancel();
    if (!_active.add(token)) return;
    if (_active.length == 1) _set(true);
  }

  /// Marks [token] as settled.
  void end(Object token) {
    if (!_active.remove(token) || _active.isNotEmpty) return;
    _settle?.cancel();
    _settle = Timer(_settleDelay, () {
      if (_active.isEmpty) _set(false);
    });
  }

  void _set(bool transitioning) {
    if (_transitioning == transitioning) return;
    _transitioning = transitioning;
    unawaited(
      SystemChannels.mouseCursor
          .invokeMethod<void>('setCursorTransitioning', {
            'transitioning': transitioning,
          })
          .catchError((Object _) {}),
    );
  }
}
