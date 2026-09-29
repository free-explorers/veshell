import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/notification/model/notification_target.dart';
import 'package:shell/notification/provider/notification_channel.dart';
import 'package:shell/notification/provider/notification_routing.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

void main() {
  const windowA = PersistentWindowId('a');
  const windowB = PersistentWindowId('b');
  const ephemeral = EphemeralWindowId('e');
  const dialog = DialogWindowId('d');
  const workspace1 = 'workspace-1';
  const workspace2 = 'workspace-2';

  IMap<WindowId, WorkspaceId> mapOf(Map<WindowId, WorkspaceId> entries) =>
      entries.lock;

  NotificationTarget route(
    WindowId? windowId, {
    Map<WindowId, WorkspaceId> workspaces = const {},
    WorkspaceId? focusedWorkspaceId = workspace1,
    Set<PersistentWindowId> displayed = const {},
    Set<EphemeralWindowId> displayedEphemeral = const {},
  }) =>
      routeForWindow(
        windowId,
        windowWorkspaceMap: mapOf(workspaces),
        focusedWorkspaceId: focusedWorkspaceId,
        displayedWindowIds: displayed.lock,
        displayedEphemeralWindowIds: displayedEphemeral.lock,
      );

  group('routeForWindow', () {
    test('no window is unresolved', () {
      expect(route(null), isA<UnresolvedNotificationTarget>());
    });

    test('window without workspace is unresolved', () {
      expect(route(windowA), isA<UnresolvedNotificationTarget>());
    });

    test('window in another workspace targets that workspace', () {
      final target = route(windowA, workspaces: {windowA: workspace2});

      expect(target, isA<WorkspaceNotificationTarget>());
      expect((target as WorkspaceNotificationTarget).workspaceId, workspace2);
    });

    test('displayed window in the focused workspace is a displayed target', () {
      final target = route(
        windowA,
        workspaces: {windowA: workspace1},
        displayed: {windowA},
      );

      expect(target, isA<DisplayedNotificationTarget>());
      expect((target as DisplayedNotificationTarget).windowId, windowA);
    });

    test('hidden window in the focused workspace is a tile target', () {
      final target = route(
        windowA,
        workspaces: {windowA: workspace1},
        displayed: {windowB},
      );

      expect(target, isA<TileNotificationTarget>());
      expect((target as TileNotificationTarget).workspaceId, workspace1);
      expect(target.windowId, windowA);
    });

    test('ephemeral window shown in the overview is hidden', () {
      final target = route(ephemeral, displayedEphemeral: {ephemeral});

      expect(target, isA<EphemeralDisplayedNotificationTarget>());
    });

    test('ephemeral window not in the overview falls back to default', () {
      final target = route(
        ephemeral,
        workspaces: {windowA: workspace1},
      );

      expect(target, isA<UnresolvedNotificationTarget>());
    });

    test('a dialog window is not routed as a tile', () {
      expect(route(dialog), isA<UnresolvedNotificationTarget>());
    });
  });

  group('visibleWindowIds', () {
    ISet<PersistentWindowId> visible(
      List<PersistentWindowId> windows,
      int selectedIndex, {
      int visibleLength = 1,
    }) => visibleWindowIds(
      windows: windows.lock,
      selectedIndex: selectedIndex,
      visibleLength: visibleLength,
    );

    test('no windows is empty', () {
      expect(visible([], 0), isEmpty);
    });

    test('the selected window is displayed', () {
      expect(visible([windowA], 0), {windowA});
    });

    test('the application launcher hides the last window', () {
      // The launcher is appended after the windows, so index 1 selects it.
      // The only window is off screen even though it is still the last one.
      expect(visible([windowA], 1), isEmpty);
    });

    test('a window after the selector scrolls the previous one away', () {
      expect(visible([windowA, windowB], 1), {windowB});
    });

    test('two visible windows are both displayed', () {
      expect(visible([windowA, windowB], 0, visibleLength: 2), {
        windowA,
        windowB,
      });
    });

    test('the launcher stays out of a two-window viewport', () {
      // Selecting the launcher shows the previous window plus the launcher:
      // only the window is reported as displayed.
      expect(visible([windowA, windowB], 2, visibleLength: 2), {windowB});
    });
  });

  group('notificationPopupTimeout', () {
    test('zero means the popup never expires on its own', () {
      expect(notificationPopupTimeout(0), isNull);
    });

    test('negative delegates to the server default', () {
      expect(notificationPopupTimeout(-1), defaultNotificationPopupDuration);
    });

    test('positive value is used verbatim', () {
      expect(notificationPopupTimeout(5000), const Duration(seconds: 5));
    });
  });

  test('channel names are stable and distinct', () {
    expect(workspaceNotificationChannel(workspace1), 'workspace:workspace-1');
    expect(windowNotificationChannel(windowA), 'window:a');
  });
}
