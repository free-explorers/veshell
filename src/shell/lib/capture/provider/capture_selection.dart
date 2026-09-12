import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

final captureSelectionProvider =
    NotifierProvider<CaptureSelection, CaptureSelectionState>(
      CaptureSelection.new,
    );

class CaptureSelectionState {
  const CaptureSelectionState({
    this.enabled = false,
    this.frameRevision = 0,
    this.layoutRevision = 0,
    this.busy = false,
    this.pointer,
    this.start,
    this.end,
  });

  final bool enabled;
  final int frameRevision;
  final int layoutRevision;
  final bool busy;
  final int? pointer;
  final Offset? start;
  final Offset? end;

  Rect? get rect => switch ((start, end)) {
    (final Offset start, final Offset end) => Rect.fromPoints(start, end),
    _ => null,
  };
}

class CaptureSelection extends Notifier<CaptureSelectionState> {
  @override
  CaptureSelectionState build() {
    final subscription = ref.read(platformManagerProvider).listen((event) {
      if (event case final MonitorLayoutChangedEvent event) {
        state = CaptureSelectionState(
          frameRevision: state.frameRevision + 1,
          layoutRevision: event.message.revision,
          busy: state.busy,
        );
      }
    });
    ref.onDispose(subscription.cancel);
    return const CaptureSelectionState();
  }

  void begin() {
    if (state.busy) {
      return;
    }
    state = CaptureSelectionState(
      enabled: true,
      frameRevision: state.frameRevision + 1,
      layoutRevision: state.layoutRevision,
    );
  }

  void cancel() {
    state = CaptureSelectionState(
      frameRevision: state.frameRevision + 1,
      layoutRevision: state.layoutRevision,
    );
  }

  void pointerDown(int pointer, Offset position) {
    if (state.enabled && state.pointer == null) {
      state = CaptureSelectionState(
        enabled: true,
        pointer: pointer,
        start: position,
        end: position,
        layoutRevision: state.layoutRevision,
        busy: state.busy,
      );
    }
  }

  void pointerMove(int pointer, Offset position) {
    if (state.pointer == pointer) {
      state = CaptureSelectionState(
        enabled: true,
        pointer: pointer,
        start: state.start,
        end: position,
        layoutRevision: state.layoutRevision,
        busy: state.busy,
      );
    }
  }

  Rect? pointerUp(int pointer, Offset position) {
    if (state.pointer != pointer) {
      return null;
    }
    final rect = Rect.fromPoints(state.start!, position);
    state = CaptureSelectionState(
      frameRevision: state.frameRevision + 1,
      layoutRevision: state.layoutRevision,
      busy: true,
    );
    return rect;
  }

  void requestOverlayFreeFrame() {
    state = CaptureSelectionState(
      frameRevision: state.frameRevision + 1,
      layoutRevision: state.layoutRevision,
      busy: state.busy,
    );
  }

  void finishCapture() {
    state = CaptureSelectionState(
      frameRevision: state.frameRevision + 1,
      layoutRevision: state.layoutRevision,
    );
  }
}
