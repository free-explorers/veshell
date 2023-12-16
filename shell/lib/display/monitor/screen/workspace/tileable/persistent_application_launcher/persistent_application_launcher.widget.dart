import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_application_launcher/app_drawer/app_drawer.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_application_launcher/app_drawer/app_grid.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/tileable.widget.dart';

/// Tileable Application Launcher to launch tileable applications
class PersistentApplicationSelector extends Tileable {
  /// Const constructor
  const PersistentApplicationSelector({required this.onSelect, super.key});
  final DesktopEntrySelectedCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.blue,
      child: AppDrawer(
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) {
    return Tab(
      child: Icon(
        MdiIcons.plus,
        color: Colors.white,
      ),
    );
  }
}
