import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'window_close_requests.g.dart';

/// Counts the times the shell asked the window shown by a tile to close.
///
/// The tile captures the window's frame on each request: once the client has
/// closed, its surface (and its texture) is gone, and that frame is what wraps
/// back into the placeholder's card (see `WindowCloseTransition`).
@riverpod
class WindowCloseRequests extends _$WindowCloseRequests {
  @override
  int build(PersistentWindowId windowId) => 0;

  void request() => state++;
}
