import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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
    final focusNode =
        useFocusScopeNode(debugLabel: 'PersistentApplicationSelector');
    useEffect(
      () {
        focusNode.canRequestFocus = isSelected;

        if (isSelected) {
          focusNode.requestFocus();
        }
        return null;
      },
      [isSelected],
    );
    return FocusScope(
      node: focusNode,
      onFocusChange: (value) {
        print('PersistentApplicationSelector focus $value');
      },
      child: ColoredBox(
        color: Colors.black26,
        child: AppDrawer(
          onSelect: onSelect,
        ),
      ),
    );
  }

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Icon(
        MdiIcons.plus,
      ),
    );
  }
}
