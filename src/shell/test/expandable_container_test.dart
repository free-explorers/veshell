import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/widget/expandable_container.dart';

Widget _root({
  required ValueNotifier<bool> visible,
  required GlobalKey<NavigatorState> navigator,
  required GlobalKey<ExpandableContainerState> owner,
}) => MaterialApp(
  navigatorKey: navigator,
  home: Scaffold(
    body: ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, show, _) => show
          ? ExpandableContainer(
              key: owner,
              builder: (context, {required isExpanded}) => TextButton(
                onPressed: () => ExpandableContainer.of(context).toggle(),
                child: Text(isExpanded ? 'Close' : 'Open'),
              ),
            )
          : const SizedBox.shrink(),
    ),
  ),
);

void main() {
  testWidgets('removing an expanded owner closes its popup without setState', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final owner = GlobalKey<ExpandableContainerState>();
    await tester.pumpWidget(
      _root(visible: visible, navigator: navigator, owner: owner),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final removedState = owner.currentState!;
    expect(navigator.currentState!.canPop(), isTrue);
    visible.value = false;
    await tester.pumpAndSettle();
    expect(removedState.mounted, isFalse);
    expect(navigator.currentState!.canPop(), isFalse);
    // Retained callbacks are harmless after the owner has been disposed.
    removedState.toggle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner cleanup does not pop an unrelated route above its popup', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final owner = GlobalKey<ExpandableContainerState>();
    await tester.pumpWidget(
      _root(visible: visible, navigator: navigator, owner: owner),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => const Scaffold(body: Text('Other route')),
      ),
    );
    await tester.pumpAndSettle();
    visible.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Other route'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal popup dismissal resets expansion state', (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final navigator = GlobalKey<NavigatorState>();
    final owner = GlobalKey<ExpandableContainerState>();
    await tester.pumpWidget(
      _root(visible: visible, navigator: navigator, owner: owner),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(owner.currentState!.isExpanded, isFalse);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
