import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

part 'animation_speed_setting.g.dart';

const animationSpeedPath = 'theme.animationSpeed';

/// Defaults mirror `extra/settings/default/settings.json`.
const animationSpeedFallback = 1.0;

/// The range a speed is kept to: below it the shell would barely move, above
/// it animations would be over before a frame shows them.
const minAnimationSpeed = 0.05;
const maxAnimationSpeed = 10.0;

/// The speed of the shell's animations: 1 as designed, 0.5 at half speed (to
/// inspect one), 2 at double speed. Applied to every animation at once
/// through Flutter's `timeDilation` (see `timeDilationForAnimationSpeed`).
@riverpod
double animationSpeedSetting(Ref ref) =>
    parseAnimationSpeed(ref.watch(jsonValueByPathProvider(animationSpeedPath)));

/// The speed stored as [value], kept to its range; the fallback when it is
/// not a positive number.
double parseAnimationSpeed(Object? value) {
  if (value is! num || !value.isFinite || value <= 0) {
    return animationSpeedFallback;
  }
  return value.toDouble().clamp(minAnimationSpeed, maxAnimationSpeed);
}

/// The `timeDilation` playing animations at [speed]: animations last
/// `timeDilation` times longer.
double timeDilationForAnimationSpeed(double speed) => 1 / speed;
