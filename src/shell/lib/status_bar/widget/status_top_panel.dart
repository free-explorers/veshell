import 'package:material_ui/material_ui.dart';
import 'package:shell/status_bar/widget/status_bar_items.dart';

/// The status bar drawn as a thin panel across the top of the workspaces,
/// like a tablet's: the system status icons, then the time, at its end. The
/// workspaces are laid out below it.
class StatusTopPanel extends StatelessWidget {
  const StatusTopPanel({super.key});

  static const double height = 28;

  @override
  Widget build(BuildContext context) {
    final colors = statusBarColors(Theme.of(context));
    return Material(
      color: colors.background,
      child: SizedBox(
        height: height,
        child: Padding(
          // The items add their own margin.
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: StatusBarItemTheme(
            foreground: colors.foreground,
            child: const Row(
              children: [
                Spacer(),
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
    );
  }
}
