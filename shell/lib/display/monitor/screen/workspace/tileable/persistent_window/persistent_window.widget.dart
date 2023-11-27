import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/tileable.widget.dart';
import 'package:shell/manager/window/window.dart';
import 'package:shell/shared/wayland/xdg_toplevel/xdg_toplevel.provider.dart';

/// Tileable Window that persist when closed
class PersistentWindowTileable extends Tileable {
  /// Const constructor
  const PersistentWindowTileable({required this.viewId, super.key});

  /// The id of the wayland surface
  final int viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Window(viewId: viewId);
  }

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) {
    final title = ref.watch(
      xdgToplevelStatesProvider(viewId).select((value) => value.title),
    );
    return Tab(child: Text(title));
  }
}
