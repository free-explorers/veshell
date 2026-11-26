import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/provider/window_art.dart';

/// The icon of the application [window] shows, from every source
/// [windowArtProvider] knows: its desktop entry, or the art of a Steam game
/// that has none.
class WindowIcon extends ConsumerWidget {
  const WindowIcon({required this.window, this.title, super.key});

  final PersistentWindow window;

  /// The name drawn by the letter fallback when the application has no
  /// desktop entry; the window's title otherwise.
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appId = window.properties.appId;
    final art = ref
        .watch(
          windowArtProvider(
            appId: appId,
            windowClass: window.properties.windowClass,
            resumeContext: window.resumeContext,
          ),
        )
        .value;
    final iconPath = art?.iconPath;
    if (iconPath == null) {
      // Until the art is known, or without any: the entry's icon or its
      // fallback, as everywhere else.
      return AppIconById(id: appId);
    }
    return AppIconByPath(
      path: iconPath,
      title: art?.name ?? title ?? window.properties.title,
    );
  }
}
