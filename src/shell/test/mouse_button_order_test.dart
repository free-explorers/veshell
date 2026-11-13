import 'dart:async';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/monitor/widget/current_screen_id.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/mouse_buttons_event/mouse_buttons_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/model/request/pointer_focus/pointer_focus.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/shared/provider/mouse_button_tracker.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wl_surface_state.dart';
import 'package:shell/wayland/widget/surface/view_input_listener.dart';

const _surfaceId = 7;
const _surfaceSize = Size(200, 150);

/// A compositor that answers pointer-focus requests only when told to, as a
/// busy one would, and records the button changes it is sent.
class _SlowFocusPlatformManager extends PlatformManager {
  static final buttons = <(int, bool)>[];
  static Completer<void> focusReply = Completer<void>();

  @override
  Stream<PlatformEvent> build() => const Stream.empty();

  @override
  Future<void> request(PlatformRequest request) async {
    if (request is PointerFocusRequest) {
      await focusReply.future;
    } else if (request is MouseButtonsEventRequest) {
      final message = request.message! as MouseButtonsEventMessage;
      for (final button in message.buttons) {
        buttons.add((button.button, button.isPressed));
      }
    }
  }
}

class _FixedSurfaceState extends WlSurfaceState {
  @override
  WlSurface build(int surfaceId) => WlSurface(
    surfaceId: surfaceId,
    role: SurfaceRole.xdgToplevel,
    texture: const SurfaceTexture(id: 1, size: _surfaceSize),
    scale: 1,
    subsurfacesBelow: IList(),
    subsurfacesAbove: IList(),
    inputRegion: Offset.zero & _surfaceSize,
  );
}

class _NoMonitor extends MonitorByName {
  @override
  Monitor? build(String monitorName) => null;
}

void main() {
  setUp(() {
    _SlowFocusPlatformManager.buttons.clear();
    _SlowFocusPlatformManager.focusReply = Completer<void>();
  });

  testWidgets(
    'a release during the press focus round trip reaches the client after it',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          platformManagerProvider.overrideWith(_SlowFocusPlatformManager.new),
          wlSurfaceStateProvider(
            _surfaceId,
          ).overrideWith(_FixedSurfaceState.new),
          monitorByNameProvider('M1').overrideWith(_NoMonitor.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CurrentMonitorName(
              name: 'M1',
              child: DeferredPointerHandler(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ViewInputListener(
                    surfaceId: _surfaceId,
                    surfaceSize: _surfaceSize,
                    child: SizedBox.fromSize(size: _surfaceSize),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(50, 50));
      await tester.pump();

      // A quick click: the release comes while the press still waits for the
      // compositor to acknowledge the pointer focus.
      await mouse.down(const Offset(50, 50));
      await mouse.up();
      await tester.pump();
      expect(_SlowFocusPlatformManager.buttons, isEmpty);

      _SlowFocusPlatformManager.focusReply.complete();
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }

      expect(_SlowFocusPlatformManager.buttons, [
        (kPrimaryMouseButton, true),
        (kPrimaryMouseButton, false),
      ]);
      expect(container.read(mouseButtonTrackerProvider).buttons, 0);
    },
  );
}
