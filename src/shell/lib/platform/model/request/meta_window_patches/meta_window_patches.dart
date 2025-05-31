import 'package:shell/platform/model/event/meta_window_patches/meta_window_patches.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';

/// [MetaWindowPatchesRequest]
class MetaWindowPatchesRequest extends PlatformRequest {
  /// constructor
  const MetaWindowPatchesRequest({
    required MetaWindowPatchMessage super.message,
    super.method = 'meta_window_patches',
  });
}
