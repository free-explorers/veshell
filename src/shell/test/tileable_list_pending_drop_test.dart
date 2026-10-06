import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
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

class _WindowTab extends PersistentWindowTileable {
  const _WindowTab(PersistentWindowId id)
    : super(windowId: id, isSelected: false);

  @override
  Widget buildPanelWidget(BuildContext context, WidgetRef ref) =>
      SizedBox(width: 120, child: Text('tab-${windowId.uuid}'));

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

class _PendingWorkspace extends WorkspaceState {
  final pending = Completer<void>();
  final inserted = <PersistentWindowId>[];

  @override
  Workspace build(WorkspaceId workspaceId) => Workspace(
    workspaceId: workspaceId,
    tileableWindowList: const IListConst([]),
    selectedIndex: 0,
    visibleLength: 1,
  );

  @override
  Future<void> insertWindow(
    PersistentWindowId windowId,
    int index, {
    bool selectWindow = false,
  }) async {
    inserted.add(windowId);
    await pending.future;
    state = state.copyWith(
      tileableWindowList: state.tileableWindowList.insert(index, windowId),
    );
  }
}

void main() {
  testWidgets('an accepted tab stays safe while its transfer is pending', (
    tester,
  ) async {
    final workspace = _PendingWorkspace();
    const window = PersistentWindowId('w1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceStateProvider('destination').overrideWith(() => workspace),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Row(
              children: [
                const SizedBox(
                  width: 200,
                  child: Center(
                    child: Draggable<PersistentWindowTileable>(
                      data: _WindowTab(window),
                      feedback: SizedBox(width: 120, height: 48),
                      child: Text('source'),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      height: 48,
                      child: CurrentWorkspaceId(
                        workspaceId: 'destination',
                        child: Consumer(
                          builder: (_, ref, child) {
                            final state = ref.watch(
                              workspaceStateProvider('destination'),
                            );
                            return TileableListView(
                              tileableList: [
                                ...state.tileableWindowList.map(_WindowTab.new),
                                const _LauncherTab(),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('source')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    // Blank panel space, not a reorder zone or launcher button.
    await gesture.moveTo(const Offset(600, 24));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(workspace.inserted, [window]);
    expect(tester.takeException(), isNull);
    expect(find.text('tab-w1'), findsOneWidget);
    workspace.pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('tab-w1'), findsOneWidget);
  });
}
