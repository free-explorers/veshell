import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/shared/widget/number_picker.dart';
import 'package:shell/shared/widget/size_reporter.dart';
import 'package:shell/status_bar/provider/status_notch_geometry.dart';
import 'package:shell/status_bar/widget/status_bar_items.dart';
import 'package:shell/status_bar/widget/status_notch_shape.dart';
import 'package:shell/theme/provider/theme.dart';

/// The status bar drawn as a notch: the system status icons and the time,
/// hung from the top of the screen right before the visible tile
/// picker of the workspace panel, above the workspaces.
///
/// It reaches the bottom of the picker, and its side next to the picker is
/// rounded concentrically with the picker's end, so the notch hugs it with
/// the gap the picker keeps from the panel's edges.
class StatusNotch extends ConsumerWidget {
  const StatusNotch({super.key});

  /// The gap the visible tile picker keeps from the panel's top and bottom,
  /// which the notch also keeps around the picker.
  static const double gap = (panelSize - NumberPicker.height) / 2;

  /// How far the notch reaches over the picker, above its rounded end.
  static const double pickerOverlap = NumberPicker.height / 2;

  static const double height = panelSize - gap;

  static const shape = StatusNotchShape(
    capRadius: NumberPicker.height / 2 + gap,
    capCenterY: gap + NumberPicker.height / 2,
    filletRadius: 24,
  );

  /// The horizontal room the side curves take before the content (whose
  /// items add their own margin).
  static const double _contentInset = NumberPicker.height / 2 + gap + 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenId = CurrentScreenId.of(context);
    final colors = statusBarColors(Theme.of(context));
    return SizeReporter(
      onSizeChanged: ref.read(statusNotchSizeProvider(screenId).notifier).set,
      child: ClipPath(
        // Clipped to its outline for hits too: the picker, and the tiles
        // beside the notch's curves, stay reachable.
        clipper: const StatusNotchClipper(shape),
        child: AbsorbPointer(
          child: Material(
            color: colors.background,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: gap,
                  left: _contentInset,
                  right: _contentInset,
                ),
                child: StatusBarItemTheme(
                  foreground: colors.foreground,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBarIcons(),
                      // The clock sits apart from the icons.
                      Padding(
                        padding: EdgeInsetsDirectional.only(start: 4),
                        child: StatusBarClock(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
