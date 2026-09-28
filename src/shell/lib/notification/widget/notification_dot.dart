import 'package:material_ui/material_ui.dart';

/// Small unread indicator dot used on workspace buttons.
class NotificationDot extends StatelessWidget {
  /// Const constructor.
  const NotificationDot({this.color, this.size = 10, super.key});

  /// Dot color, defaults to the theme error color.
  final Color? color;

  /// Dot diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).colorScheme.surface;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.error,
        shape: BoxShape.circle,
        border: Border.all(color: background, width: 2),
      ),
    );
  }
}
