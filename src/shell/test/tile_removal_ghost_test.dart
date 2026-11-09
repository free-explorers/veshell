import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/saturation_filter.dart';
import 'package:shell/tile_grab/widget/tile_drop_slot.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

const _windowId = PersistentWindowId('gone');

/// A workspace showing its only window, so a slot can be tested on its own.
class _Workspace extends WorkspaceState {
  @override
  Workspace build(WorkspaceId workspaceId) {
    ref.keepAlive();
    return Workspace(
      workspaceId: workspaceId,
      tileableWindowList: const IListConst([_windowId]),
      selectedIndex: 0,
      visibleLength: 1,
    );
  }
}

void main() {
  testWidgets('a removed tile stays and dims in its slot while the incoming '
      'tile slides over it, then goes', (tester) async {
    final container = ProviderContainer(
      overrides: [workspaceStateProvider('ws').overrideWith(_Workspace.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 300,
              child: TileDropSlot(
                workspaceId: 'ws',
                index: 0,
                windowId: _windowId,
                initialDisplayIndex: 1,
                leaving: SizedBox(
                  key: ValueKey('ghost'),
                  width: 400,
                  height: 300,
                ),
                child: SizedBox(
                  key: ValueKey('incoming'),
                  width: 400,
                  height: 300,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    double brightness() => tester
        .widget<SaturationFilter>(
          find.byKey(const ValueKey('tile-removal-dim')),
        )
        .brightness;

    // The incoming tile starts a slot to the right; the ghost is in place.
    expect(tester.getTopLeft(find.byKey(const ValueKey('incoming'))).dx, 400);
    expect(tester.getTopLeft(find.byKey(const ValueKey('ghost'))).dx, 0);
    expect(brightness(), 1);

    await tester.pump(const Duration(milliseconds: 120));
    final midway = tester.getTopLeft(find.byKey(const ValueKey('incoming'))).dx;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(400));
    expect(tester.getTopLeft(find.byKey(const ValueKey('ghost'))).dx, 0);
    // It darkens as it is covered.
    expect(brightness(), inExclusiveRange(1 - tileRemovalDim, 1));

    // Once covered, it is gone, and does not come back with the next slide.
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('incoming'))).dx, 0);
    expect(find.byKey(const ValueKey('ghost')), findsNothing);
  });
}
