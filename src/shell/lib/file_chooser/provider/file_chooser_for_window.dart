import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_chooser/model/file_chooser_request/file_chooser_request.serializable.dart';
import 'package:shell/file_chooser/provider/file_chooser_request.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'file_chooser_for_window.g.dart';

/// The file chooser request whose requesting window is owned by [windowId].
///
/// The window container watches this to render the trusted dialog inside
/// itself, attached to the window that asked for it (like a native dialog).
/// `null` unless the requester resolves to exactly this window.
@riverpod
FileChooserRequestMessage? fileChooserForWindow(Ref ref, WindowId windowId) {
  final request = ref.watch(fileChooserRequestProvider);
  final metaWindowId = request?.metaWindowId;
  if (request == null || metaWindowId == null) {
    return null;
  }
  final owner = ref.watch(metaWindowWindowMapProvider)[metaWindowId];
  return owner == windowId ? request : null;
}
