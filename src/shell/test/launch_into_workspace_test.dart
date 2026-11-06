import 'dart:ui' as ui;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer_desktop_entries.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/monitor/provider/monitor_by_view_id.dart';
import 'package:shell/monitor/provider/platform_focused_view.dart';
import 'package:shell/monitor/widget/current_screen_id.dart' as monitor;
import 'package:shell/screen/model/screen_manager_state.serializable.dart';
import 'package:shell/screen/provider/screen_for_view.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/settings/provider/state/focus_indicator_setting.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_manager_state.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/workspace/model/workspace.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/launch_morph.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/persistent_application_launcher.dart';
import 'package:shell/workspace/widget/workspace.dart';

const _screen = 'screen-1';
const _workspace = 'ws-1';

class _NoLocalizedEntry extends LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => null;
}

class _FakeWindowManager extends WindowManager {
  @override
  WindowManagerState build() => WindowManagerState(windows: <WindowId>{}.lock);

  @override
  PersistentWindowId createPersistentWindowForDesktopEntry(
    LocalizedDesktopEntry entry,
  ) => const PersistentWindowId('new');
}

class _FakeWindowState extends PersistentWindowState {
  @override
  PersistentWindow build(PersistentWindowId windowId) => PersistentWindow(
    windowId: windowId,
    properties: const WindowProperties(appId: 'Alpha', title: 'Alpha'),
  );
}

/// Inserts like the real one: after an `await` (its category lookup).
class _FakeWorkspaceState extends WorkspaceState {
  @override
  Workspace build(WorkspaceId workspaceId) {
    ref.keepAlive();
    return Workspace(
      workspaceId: workspaceId,
      tileableWindowList: <PersistentWindowId>[].lock,
      selectedIndex: 0,
      visibleLength: 1,
    );
  }

  @override
  Future<void> insertWindow(
    PersistentWindowId windowId,
    int index, {
    bool selectWindow = false,
  }) async {
    await Future<void>.delayed(Duration.zero);
    state = state.copyWith(
      tileableWindowList: state.tileableWindowList.insert(index, windowId),
      selectedIndex: selectWindow ? index : state.selectedIndex,
    );
  }
}

LocalizedDesktopEntry _entry(String name) => LocalizedDesktopEntry(
  desktopEntry: DesktopEntry(entries: const {}, id: name),
  entries: {DesktopEntryKey.name.string: name},
);

void main() {
  testWidgets('the launcher slides aside under the launched tile', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        screenManagerProvider.overrideWithValue(
          ScreenManagerState(screenIds: {_screen}.lock),
        ),
        monitorByViewIdProvider(1).overrideWithValue('M'),
        screenForViewProvider(1).overrideWithValue(_screen),
        windowManagerProvider.overrideWith(_FakeWindowManager.new),
        focusIndicatorSettingProvider.overrideWithValue(FocusIndicator.none),
        persistentWindowStateProvider.overrideWith2((_) => _FakeWindowState()),
        workspaceStateProvider(
          _workspace,
        ).overrideWith(_FakeWorkspaceState.new),
        appDrawerDesktopEntriesProvider.overrideWith(
          (ref) async => [_entry('Alpha'), _entry('Beta')],
        ),
        localizedDesktopEntryForIdProvider.overrideWith2(
          (_) => _NoLocalizedEntry(),
        ),
        iconFileFromQueryProvider.overrideWith((ref, query) async => null),
      ],
    );
    addTearDown(container.dispose);
    container.read(platformFocusedViewIdProvider.notifier).set(1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: monitor.CurrentMonitorName(
            name: 'M',
            child: CurrentScreenId(
              screenId: _screen,
              child: Scaffold(
                body: RepaintBoundary(
                  child: WorkspaceWidget(
                    workspaceId: _workspace,
                    isSelected: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final launcher = find.byType(
      PersistentApplicationLauncher,
      skipOffstage: false,
    );
    final workspace = find.byType(WorkspaceWidget);
    final workspaceRect = tester.getRect(workspace);

    /// The color painted at [point], in global coordinates.
    Future<ui.Color> colorAt(Offset point) async {
      final image = (await tester.runAsync(
        () => captureImage(tester.element(workspace)),
      ))!;
      final bytes = (await tester.runAsync(image.toByteData))!;
      final local = point - workspaceRect.topLeft;
      final offset = (local.dy.toInt() * image.width + local.dx.toInt()) * 4;
      return ui.Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }

    // A spot of plain launcher background: its bottom-left margin, followed
    // as the launcher moves.
    Offset probe() => tester.getBottomLeft(launcher) + const Offset(4, -4);
    final launcherColor = await colorAt(probe());
    final start = tester.getTopLeft(launcher).dx;

    await tester.tap(find.text('Alpha'));
    // The tile is inserted after an `await`: from then on the morph runs.
    await tester.pump();
    await tester.pump();
    const step = Duration(milliseconds: 16);
    var elapsed = Duration.zero;
    var last = start;
    while (elapsed < launchMorphDuration) {
      await tester.pump(step);
      elapsed += step;
      final x = tester.getTopLeft(launcher).dx;
      expect(x, greaterThanOrEqualTo(last), reason: 'at $elapsed');
      last = x;
      if (elapsed <= launchMorphDuration * 0.3) {
        // Held while the launched item lifts out of it as a card.
        expect(x, start, reason: 'at $elapsed');
      }
      if (workspaceRect.contains(probe())) {
        // Painted all along, sliding: not hidden by its slot being off view
        // (the backdrop fading in over it only just tints it).
        final color = await colorAt(probe());
        expect(color.a, 1, reason: 'at $elapsed');
        for (final (channel, expected) in [
          (color.r, launcherColor.r),
          (color.g, launcherColor.g),
          (color.b, launcherColor.b),
        ]) {
          expect(channel, closeTo(expected, 0.05), reason: 'at $elapsed');
        }
      }
    }
    // In its own slot as the card lands (then, out of view, no longer built).
    expect(last, closeTo(start + workspaceRect.width, 1));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
  });
}
