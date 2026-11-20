import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/provider/overview_state.dart';
import 'package:shell/overview/widget/overview_blur_target.dart';
import 'package:shell/settings/provider/state/optimized_overview_setting.dart';

/// Stands in for `WorkspaceWidget`: it takes the keyboard when it mounts, the
/// way the real one does from its `workspaceCanFocus` effect.
class _WorkspaceLike extends HookWidget {
  const _WorkspaceLike({required this.onMount});

  final void Function() onMount;

  @override
  Widget build(BuildContext context) {
    final node = useFocusScopeNode(debugLabel: 'WorkspaceScope');
    useEffect(() {
      onMount();
      node.requestFocus();
      return null;
    }, []);
    return FocusScope(
      node: node,
      autofocus: true,
      child: const SizedBox.expand(),
    );
  }
}

void main() {
  const screenId = 'test';

  for (final optimized in [true, false]) {
    final variant = optimized ? 'baked frost' : 'live frost';
    testWidgets(
      'opening the overview does not rebuild the screen behind it ($variant)',
      (tester) => _expectScreenSurvivesOverview(
        tester,
        screenId: screenId,
        optimized: optimized,
      ),
    );
  }

  for (final optimized in [true, false]) {
    testWidgets(
      'the settled frost is ${optimized ? '' : 'not '}baked into an image '
      'when theme.optimizedOverview is ${optimized ? 'on' : 'off'}',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            optimizedOverviewSettingProvider.overrideWithValue(optimized),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: OverviewBlurTarget(
                screenId: screenId,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        );
        expect(find.byType(RawImage), findsNothing);

        container.read(overviewStateProvider(screenId).notifier).toggle();
        await tester.pumpAndSettle();
        // The capture is real engine work: let it complete outside the fake
        // clock, then paint the frame that swaps it in.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(
          find.byType(RawImage),
          optimized ? findsOneWidget : findsNothing,
        );

        // Closing thaws back to the live frost before the ramp.
        container.read(overviewStateProvider(screenId).notifier).toggle();
        await tester.pump();
        expect(find.byType(RawImage), findsNothing);
        await tester.pumpAndSettle();
      },
    );
  }
}

Future<void> _expectScreenSurvivesOverview(
  WidgetTester tester, {
  required String screenId,
  required bool optimized,
}) async {
  // The frost ramps the whole screen on every open and close. If it
  // re-inflates what it frosts, every workspace, tile and live surface behind
  // the overview is rebuilt from scratch: their state is lost and their focus
  // hand-offs run again, which took the keyboard back from the overview's
  // search field — Super+WASD then moved workspaces instead of the results.
  final container = ProviderContainer(
    overrides: [optimizedOverviewSettingProvider.overrideWithValue(optimized)],
  );
  addTearDown(container.dispose);
  final search = FocusNode(debugLabel: 'OverviewSearch');
  addTearDown(search.dispose);
  var mounts = 0;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Stack(
          children: [
            // The screen behind the overview, holding the keyboard through a
            // workspace.
            OverviewBlurTarget(
              screenId: screenId,
              child: _WorkspaceLike(onMount: () => mounts++),
            ),
            // Stands in for the overview overlay, which takes the keyboard
            // when it opens.
            Focus(focusNode: search, child: const SizedBox.expand()),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(mounts, 1, reason: 'the workspace mounts once');

  search.requestFocus();
  await tester.pump();
  expect(search.hasPrimaryFocus, isTrue);

  container.read(overviewStateProvider(screenId).notifier).toggle();
  await tester.pumpAndSettle();
  expect(mounts, 1, reason: 'the screen frost must not remount the screen');
  expect(
    search.hasPrimaryFocus,
    isTrue,
    reason: 'nor take the keyboard back from the overlay',
  );

  // Closing ramps the frost back down; the screen must survive that too.
  container.read(overviewStateProvider(screenId).notifier).toggle();
  await tester.pumpAndSettle();
  expect(mounts, 1, reason: 'nor when the frost clears');
}
