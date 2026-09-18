import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigator_key_for_view.g.dart';

/// Stable navigator key for a Flutter view (there is one `MaterialApp`,
/// and therefore one root Navigator, per monitor).
///
/// Trusted shell dialogs (Polkit authentication) are pushed on the
/// focused monitor's navigator through this key.
@Riverpod(keepAlive: true)
GlobalKey<NavigatorState> navigatorKeyForView(Ref ref, int viewId) {
  return GlobalKey<NavigatorState>(debugLabel: 'monitor-navigator-$viewId');
}
