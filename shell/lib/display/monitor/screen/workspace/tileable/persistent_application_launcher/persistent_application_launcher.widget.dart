import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_application_launcher/app_drawer/app_drawer.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/tileable.widget.dart';

/// Tileable Application Launcher to launch tileable applications
class PersistentApplicationLauncher extends Tileable {
  /// Const constructor
  const PersistentApplicationLauncher({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.blue,
      child: const AppDrawer(),
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
