import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../generated/util/state/display_brightness_state.freezed.dart';

final displayBrightnessStateProvider =
    StateNotifierProvider<DisplayBrightnessStateNotifier, DisplayBrightnessState>((ref) {
  return DisplayBrightnessStateNotifier();
});

@freezed
class DisplayBrightnessState with _$DisplayBrightnessState {
  const factory DisplayBrightnessState({
    required bool available,
    required File brightnessFile,
    required int maxBrightness,
    required double brightness,
    required double savedBrightness,
  }) = _DisplayBrightnessState;
}

const _backlightsDirectory = "/sys/class/backlight";

class DisplayBrightnessStateNotifier extends StateNotifier<DisplayBrightnessState> {
  DisplayBrightnessStateNotifier()
      : super(
          DisplayBrightnessState(
            available: false,
            brightnessFile: File(""),
            maxBrightness: 1000,
            brightness: 1.0,
            savedBrightness: 1.0,
          ),
        ) {
    _init();
  }

  Future<void> _init() async {
    try {
      DisplayBrightnessState defaultState = await _getDefault();
      defaultState.brightnessFile.watch(events: FileSystemEvent.modify).forEach((_) async {
        String brightnessString = await state.brightnessFile.readAsString();
        double measuredBrightness = int.parse(brightnessString) / state.maxBrightness;
        measuredBrightness = measuredBrightness.clamp(0.0, 1.0);
        state = state.copyWith(brightness: _getPerceivedBrightness(measuredBrightness));
      });
      state = defaultState;

      // If there's a bug and the screen is off when the compositor starts, turn it on.
      if (brightness == 0.0) {
        setBrightness(1.0);
      }
    } catch (e) {
      // Retry.
      await Future.delayed(const Duration(seconds: 1));
      _init();
    }
  }

  double get brightness => state.brightness;

  Future<void> setBrightness(double value) async {
    int measuredBrightness = (_getMeasuredBrightness(value) * state.maxBrightness).round();
    await state.brightnessFile.writeAsString("$measuredBrightness", flush: true);
  }

  void saveBrightness() {
    state = state.copyWith(savedBrightness: state.brightness);
  }

  Future<void> restoreBrightness() => setBrightness(state.savedBrightness);
}

Future<DisplayBrightnessState> _getDefault() async {
  FileSystemEntity backlight = await Directory(_backlightsDirectory).list().first;

  File brightnessFile = File("${backlight.absolute.path}/brightness");
  File maxBrightnessFile = File("${backlight.absolute.path}/max_brightness");

  int maxBrightness = int.parse(await maxBrightnessFile.readAsString());
  double measuredBrightness = int.parse(await brightnessFile.readAsString()) / maxBrightness;

  return DisplayBrightnessState(
    available: true,
    brightnessFile: brightnessFile,
    maxBrightness: maxBrightness,
    brightness: _getPerceivedBrightness(measuredBrightness),
    savedBrightness: 0.0,
  );
}

double _getPerceivedBrightness(double measuredBrightness) => sqrt(measuredBrightness);

double _getMeasuredBrightness(double perceivedBrightness) => perceivedBrightness * perceivedBrightness;
