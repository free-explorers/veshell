import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenith/platform_api.dart';

part '../../generated/util/state/ui_mode_state.g.dart';

enum UiMode {
  mobile,
  desktop,
}

@Riverpod(keepAlive: true)
class UiModeState extends _$UiModeState {
  @override
  UiMode build() => UiMode.desktop;

  set mode(UiMode mode) {
    state = mode;
    switch (mode) {
      case UiMode.mobile:
        ref.read(platformApiProvider.notifier).openWindowsMaximized(true);
      case UiMode.desktop:
        ref.read(platformApiProvider.notifier).openWindowsMaximized(false);
    }
  }
}
