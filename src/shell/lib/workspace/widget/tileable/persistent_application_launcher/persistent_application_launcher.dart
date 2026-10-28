import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_drawer.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_grid.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';

/// Tileable Application Launcher to launch tileable applications
class PersistentApplicationSelector extends Tileable {
  /// Const constructor
  const PersistentApplicationSelector({
    required this.onSelect,
    required super.isSelected,
    super.key,
  });
  final DesktopEntrySelectedCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusNode = useFocusScopeNode(
      debugLabel: 'PersistentApplicationSelector',
    );
    // The search field is the launcher's keyboard. The tile owns its node so it
    // can hand the caret over when it takes the keyboard, the way a window tile
    // owns the node of the window it shows.
    final searchFocusNode = useFocusNode(debugLabel: 'AppDrawerSearch');

    // The focus gates live on the scope widget below, not on the node: a
    // `FocusScopeNode` reports its `descendantsAreFocusable` as
    // `canRequestFocus && ...`, so writing that value back onto the node
    // latches it to false the first time the tile is deselected and the search
    // field becomes unreachable (see `WorkspaceWidget`).
    useEffect(() {
      if (isSelected) {
        focusNode.requestFocus();
        focusLog.info('PersistentApplicationSelector requesting focus');
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
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: AppDrawer(onSelect: onSelect, searchFocusNode: searchFocusNode),
      ),
    );
  }

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef removeSurface) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: ShellIcon(MdiIcons.plus),
    );
  }

  @override
  List<Widget> buildMenuChildren(BuildContext context, WidgetRef ref) {
    return [];
  }
}
