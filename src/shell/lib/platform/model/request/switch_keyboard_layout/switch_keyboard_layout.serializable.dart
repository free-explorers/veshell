import 'package:shell/platform/model/request/platform_request.dart';

/// [SwitchKeyboardLayoutRequest]
///
/// Asks the compositor to advance the seat's keyboard to the next configured
/// xkb layout. The layouts themselves live in `keyboard.layout`; this request
/// carries no payload.
class SwitchKeyboardLayoutRequest extends PlatformRequest {
  ///
  const SwitchKeyboardLayoutRequest({super.method = 'switch_keyboard_layout'});
}
