import 'package:shell/platform/model/event/meta_popup_patches/meta_popup_patches.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';

/// [MetaPopupPatchesRequest]
class MetaPopupPatchesRequest extends PlatformRequest {
  /// constructor
  const MetaPopupPatchesRequest({
    required MetaPopupPatchMessage super.message,
    super.method = 'meta_popup_patches',
  });
}
