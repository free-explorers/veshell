import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part '../../../generated/ui/mobile/state/app_drawer_state.freezed.dart';

part '../../../generated/ui/mobile/state/app_drawer_state.g.dart';

@Riverpod(keepAlive: true)
class AppDrawerNotifier extends _$AppDrawerNotifier {
  @override
  AppDrawerState build() {
    return const AppDrawerState(
      /// The drawer is in a state where a drag can be engaged, e.g. the drawer is fully scrolled at the top.
      draggable: false,

      /// The user is actively dragging the drawer.
      dragging: false,

      /// You can interact with the drawer and taps won't just go though it.
      interactable: false,

      /// The finger velocity when the drag ends.
      dragVelocity: 0,

      /// 0 means the drawer is fully open.
      /// Equal to slideDistance when it's fully closed.
      offset: 300,

      /// The amount the user has to drag to open the drawer.
      slideDistance: 300,

      /// Event to notify the drawer to initiate the closing animations.
      /// Just assigning a new Object() will do the trick because 2 different Object instances will always be unequal.
      closePanel: Object(),

      // The panel is fully closed.
      fullyClosed: true,
    );
  }

  @override
  set state(AppDrawerState value) {
    super.state = value;
  }

  void update(AppDrawerState Function(AppDrawerState) callback) {
    super.state = callback(state);
  }
}

@freezed
class AppDrawerState with _$AppDrawerState {
  const factory AppDrawerState({
    required bool draggable,
    required bool dragging,
    required bool interactable,
    required double dragVelocity,
    required double offset,
    required double slideDistance,
    required Object closePanel,
    required bool fullyClosed,
  }) = _AppDrawerState;
}
