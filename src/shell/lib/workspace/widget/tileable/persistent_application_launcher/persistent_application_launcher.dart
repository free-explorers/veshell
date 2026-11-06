import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/model/launch_morph_request.dart';
import 'package:shell/workspace/provider/launch_morphs.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_drawer.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';

/// The [Tileable] that launches applications as persistent window tiles (see
/// `docs/specifications/persistent_application_launcher.md`).
class PersistentApplicationLauncher extends Tileable {
  /// Const constructor
  const PersistentApplicationLauncher({
    required this.onSelect,
    required super.isSelected,
    super.key,
  });

  /// Creates the tile for the given entry, in the launcher's place; returns
  /// its window.
  final PersistentWindowId Function(LocalizedDesktopEntry entry) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusNode = useFocusScopeNode(
      debugLabel: 'PersistentApplicationLauncher',
    );
    // The search field is the launcher's keyboard. The tile owns its node so it
    // can hand the caret over when it takes the keyboard, the way a window tile
    // owns the node of the window it shows.
    final searchFocusNode = useFocusNode(debugLabel: 'AppDrawerSearch');

    final tileKey = useMemoized(GlobalKey.new);

    // The tile is created at once, in the launcher's place, and opens with
    // the launched item morphing into its placeholder (`LaunchMorph`).
    Future<void> launch(LocalizedDesktopEntry entry, LaunchOrigin? origin) {
      final box = tileKey.currentContext?.findRenderObject();
      final launcherRect =
          origin != null &&
              box is RenderBox &&
              box.hasSize &&
              !MediaQuery.disableAnimationsOf(context)
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      final windowId = onSelect(entry);
      if (launcherRect != null && origin != null) {
        ref
            .read(launchMorphsProvider.notifier)
            .start(
              windowId,
              LaunchMorphRequest(
                entry: entry,
                origin: origin,
                launcherRect: launcherRect,
              ),
            );
      }
      return Future.value();
    }

    // The focus gates live on the scope widget below, not on the node: a
    // `FocusScopeNode` reports its `descendantsAreFocusable` as
    // `canRequestFocus && ...`, so writing that value back onto the node
    // latches it to false the first time the tile is deselected and the search
    // field becomes unreachable (see `WorkspaceWidget`).
    useEffect(() {
      if (isSelected) {
        focusNode.requestFocus();
        focusLog.info('PersistentApplicationLauncher requesting focus');
      }
      return null;
    }, [isSelected]);

    return FocusScope(
      node: focusNode,
      // `autofocus` as well as the request above: at mount the request can land
      // before the scope's `canRequestFocus` gate has been written and be
      // dropped, while a pending autofocus is applied at the end of the frame,
      // by which time the gate is set (`WorkspaceWidget` relies on the same
      // pair). It also re-takes the keyboard when the tile is reactivated.
      autofocus: isSelected,
      canRequestFocus: isSelected,
      // An unselected tile must not hold the keyboard, nor let any descendant
      // hold it: deselecting the launcher has to take the caret back out of the
      // search field.
      descendantsAreFocusable: isSelected,
      onFocusChange: (value) {
        if (!value) {
          return;
        }
        // Whenever the tile's scope takes the keyboard, the search field gets
        // it. Asking the scope to autofocus the field — instead of focusing the
        // scope itself — is also what settles the order against the
        // `requestFocus` above: pending autofocuses are applied after the
        // frame's explicit requests, so the field wins. Focusing the scope left
        // the caret on the scope, where typing filtered nothing.
        focusNode.autofocus(searchFocusNode);
      },
      child: ColoredBox(
        key: tileKey,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: AppDrawer(onSelect: launch, searchFocusNode: searchFocusNode),
      ),
    );
  }

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: ShellIcon(MdiIcons.plus),
    );
  }

  /// The launcher has no tile actions (a window tile offers its own here).
  @override
  List<Widget> buildMenuChildren(BuildContext context, WidgetRef ref) {
    return const [];
  }
}
