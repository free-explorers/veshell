// The ProviderScope a helper builds here is the root scope handed to
// pumpWidget; the lint only recognises a root scope written inline there.
// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/current_workspace_id.dart';
import 'package:shell/workspace/widget/tileable/persistent_window/persistent_window.dart';
import 'package:shell/workspace/widget/tileable/tileable.dart';
import 'package:shell/workspace/widget/tileable_list.dart';

int _panelMounts = 0;

/// Counts how often the panel content is inserted. A remount means the item
/// subtree (and with it the pointer's ink ripple) was thrown away.
class _CountingPanel extends StatefulWidget {
  const _CountingPanel({required this.label});

  final String label;

  @override
  State<_CountingPanel> createState() => _CountingPanelState();
}

class _CountingPanelState extends State<_CountingPanel> {
  @override
  void initState() {
    super.initState();
    _panelMounts++;
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 120, child: Text(widget.label));
}

class _WindowTab extends PersistentWindowTileable {
  const _WindowTab(PersistentWindowId id)
    : super(windowId: id, isSelected: false);

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) =>
      _CountingPanel(label: 'tab-${windowId.uuid}');

  @override
  List<Widget> buildMenuChildren(BuildContext context, WidgetRef ref) => [];
}

class _LauncherTab extends Tileable {
  const _LauncherTab() : super(isSelected: false);

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) =>
      const SizedBox(width: 48, child: Text('launcher'));

  @override
  List<Widget> buildMenuChildren(BuildContext context, WidgetRef ref) => [];
}

class _StaticWorkspace extends WorkspaceState {
  @override
  Workspace build(WorkspaceId workspaceId) => Workspace(
    workspaceId: workspaceId,
    tileableWindowList: const IListConst([PersistentWindowId('w1')]),
    selectedIndex: 0,
    visibleLength: 1,
  );
}

Widget _wrap(List<Tileable> tileableList) => ProviderScope(
  overrides: [workspaceStateProvider('ws').overrideWith(_StaticWorkspace.new)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 48,
        child: CurrentWorkspaceId(
          workspaceId: 'ws',
          child: TileableListView(tileableList: tileableList),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a workspace rebuild keeps panel items mounted', (tester) async {
    _panelMounts = 0;
    const window = PersistentWindowId('w1');
    final first = _wrap([const _WindowTab(window), const _LauncherTab()]);
    await tester.pumpWidget(first);
    await tester.pump();
    expect(_panelMounts, 1);

    // Selecting a tileable rebuilds the workspace with fresh `Tileable`
    // instances; the panel item must keep its element (and its ink ripple).
    final second = _wrap([const _WindowTab(window), const _LauncherTab()]);
    await tester.pumpWidget(second);
    await tester.pump();

    expect(_panelMounts, 1);
  });
}
