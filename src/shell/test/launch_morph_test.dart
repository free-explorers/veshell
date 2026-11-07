import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/app_drawer.dart';
import 'package:shell/application/provider/app_drawer_desktop_entries.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/widget/window_placeholder.dart';
import 'package:shell/workspace/provider/launch_morphs.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_drawer.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/app_drawer/app_grid.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/launch_morph.dart';
import 'package:shell/workspace/widget/tileable/persistent_application_launcher/persistent_application_launcher.dart';

class _NoLocalizedEntry extends LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => null;
}

/// Resolves late, with a long command line (like Audacity's): the
/// placeholder's card is laid out again once it arrives.
class _LateLocalizedEntry extends LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return LocalizedDesktopEntry(
      desktopEntry: DesktopEntry(entries: const {}, id: appId),
      entries: {
        DesktopEntryKey.name.string: appId,
        DesktopEntryKey.exec.string:
            'env GDK_BACKEND=x11 UBUNTU_MENUPROXY=0 $appId %F',
      },
    );
  }
}

LocalizedDesktopEntry _entry(String name) => LocalizedDesktopEntry(
  desktopEntry: DesktopEntry(entries: const {}, id: name),
  entries: {DesktopEntryKey.name.string: name},
);

/// Stands in for the workspace: the launcher, until a launch creates a tile,
/// which takes its place and plays the registered morph (as
/// `PersistentWindowTileable` does).
class _Host extends ConsumerWidget {
  const _Host({required this.launched});

  final List<PersistentWindow> launched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final morphs = ref.watch(launchMorphsProvider);
    if (launched.isEmpty) {
      return PersistentApplicationLauncher(
        isSelected: true,
        onSelect: (entry) {
          final window = PersistentWindow(
            windowId: PersistentWindowId('tile-${launched.length}'),
            properties: WindowProperties(
              appId: entry.desktopEntry.id ?? '',
              title: entry.entries[DesktopEntryKey.name.string],
            ),
          );
          launched.add(window);
          (context as Element).markNeedsBuild();
          return window.windowId;
        },
      );
    }
    final window = launched.last;
    final request = morphs[window.windowId];
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: request == null ? 1 : 0,
          child: WindowPlaceholder(isSelected: true, window: window),
        ),
        if (request != null)
          LaunchMorph(
            key: ObjectKey(request),
            window: window,
            request: request,
            onDone: () =>
                ref.read(launchMorphsProvider.notifier).finish(window.windowId),
          ),
      ],
    );
  }
}

/// Pumps the launcher with [names]; returns the tiles it creates.
Future<List<PersistentWindow>> _pump(
  WidgetTester tester, {
  bool disableAnimations = false,
  List<String> names = const ['Alpha', 'Beta'],
  bool lateEntries = false,
  Size size = const Size(800, 600),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final launched = <PersistentWindow>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDrawerDesktopEntriesProvider.overrideWith(
          (ref) async => [for (final name in names) _entry(name)],
        ),
        localizedDesktopEntryForIdProvider.overrideWith2(
          (_) => lateEntries ? _LateLocalizedEntry() : _NoLocalizedEntry(),
        ),
        iconFileFromQueryProvider.overrideWith((ref, query) async => null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(body: _Host(launched: launched)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return launched;
}

Finder _entryNamed(String name) => find.byWidgetPredicate(
  (w) =>
      w is AppEntry &&
      w.desktopEntry.entries[DesktopEntryKey.name.string] == name,
);

Finder get _morph => find.byType(LaunchMorph);

Finder get _flyingIcon => find.byKey(LaunchMorph.flyingIconKey);

Finder get _flyingCard => find.byKey(LaunchMorph.flyingCardKey);

Finder get _flyingTitle => find.byKey(LaunchMorph.flyingTitleKey);

Finder get _content => find.byWidgetPredicate(
  (w) => w is WindowPlaceholder && w.part == PlaceholderPart.cardContent,
);

LaunchMorphRequest? _request(WidgetTester tester, PersistentWindow window) =>
    ProviderScope.containerOf(
      tester.element(find.byType(_Host)),
    ).read(launchMorphsProvider)[window.windowId];

/// Pumps until the morph has started (its placeholder's entry is loaded and
/// measured).
Future<void> _untilStarted(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

/// Checks the morph's last frame: everything sits where the placeholder has
/// it.
void _expectLanded(WidgetTester tester, String name) {
  expect(_morph, findsOneWidget);
  expect(
    tester.getRect(_flyingIcon),
    rectMoreOrLessEquals(
      tester.getRect(
        find.descendant(of: _content, matching: find.byType(AppIconById)),
      ),
    ),
  );
  expect(
    tester.getRect(_flyingTitle),
    rectMoreOrLessEquals(
      tester.getRect(find.descendant(of: _content, matching: find.text(name))),
    ),
  );
}

void main() {
  testWidgets('a launch creates the tile at once, which opens with the morph', (
    tester,
  ) async {
    final launched = await _pump(tester);
    final item = tester.getRect(_entryNamed('Alpha'));

    await tester.tap(_entryNamed('Alpha'));
    await tester.pump();

    expect(launched.map((w) => w.properties.title), ['Alpha']);
    final request = _request(tester, launched.single)!;
    expect(request.origin.item, rectMoreOrLessEquals(item));
    expect(request.launcherRect, const Rect.fromLTWH(0, 0, 800, 600));
    expect(_morph, findsOneWidget);
    // The launcher is shown once, as itself: the tile does not draw a copy of
    // it, only the backdrop fading in.
    expect(
      find.descendant(of: _morph, matching: find.byType(RawImage)),
      findsNothing,
    );

    await tester.pumpAndSettle();
    // Over: the registry lets go, and the tile shows its placeholder.
    expect(_request(tester, launched.single), isNull);
    expect(_morph, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the item lifts out as a card that lands on the placeholder '
      'card, its icon and label on the icon and title', (tester) async {
    await _pump(tester);
    final item = tester.getRect(_entryNamed('Alpha'));
    final itemIcon = tester.getRect(
      find.descendant(
        of: _entryNamed('Alpha'),
        matching: find.byType(AspectRatio),
      ),
    );

    await tester.tap(_entryNamed('Alpha'));
    await tester.pump();
    expect(tester.getRect(_flyingCard), rectMoreOrLessEquals(item));
    expect(tester.getRect(_flyingIcon), rectMoreOrLessEquals(itemIcon));
    await _untilStarted(tester);
    expect(tester.getRect(_flyingCard), rectMoreOrLessEquals(item));

    await tester.pump(launchMorphDuration);
    expect(
      tester.getRect(_flyingCard),
      rectMoreOrLessEquals(
        const Rect.fromLTRB(
          800 * placeholderCardInset,
          600 * placeholderCardInset,
          800 * (1 - placeholderCardInset),
          600 * (1 - placeholderCardInset),
        ),
      ),
    );
    _expectLanded(tester, 'Alpha');
    await tester.pumpAndSettle();
  });

  testWidgets('the card is opaque until the backdrop is in', (tester) async {
    await _pump(tester);
    Color cardColor() =>
        ((tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: _flyingCard,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration)
            .color)!;

    await tester.tap(_entryNamed('Alpha'));
    await _untilStarted(tester);
    for (var step = 0; step < 3; step++) {
      await tester.pump(launchMorphDuration * 0.08);
      expect(cardColor().a, 1);
    }
    await tester.pump(launchMorphDuration * 0.76);
    // Landed: the placeholder card's translucent color.
    expect(cardColor().a, lessThan(1));
    await tester.pumpAndSettle();
  });

  testWidgets('Enter morphs the item it launches', (tester) async {
    final launched = await _pump(tester);
    await tester.showKeyboard(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final item = tester.getRect(_entryNamed('Beta'));

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(launched.map((w) => w.properties.title), ['Beta']);
    expect(tester.getRect(_flyingCard), rectMoreOrLessEquals(item));
    await tester.pumpAndSettle();
  });

  testWidgets('without animations, the tile opens as it is', (tester) async {
    final launched = await _pump(tester, disableAnimations: true);

    await tester.tap(_entryNamed('Alpha'));
    await tester.pump();

    expect(launched, hasLength(1));
    expect(_request(tester, launched.single), isNull);
    expect(_morph, findsNothing);
  });

  group('lands on the placeholder from anywhere in the grid', () {
    final names = [
      for (var i = 0; i < 40; i++) 'App${i.toString().padLeft(2, '0')}',
    ];
    // First item, another column, another row, and one reached by scrolling;
    // at a desktop tile's size (the recorded one: 2520x1350), where the
    // command line's width moves the icon and the title once it loads.
    for (final name in ['App00', 'App04', 'App13', 'App33']) {
      testWidgets(name, (tester) async {
        await _pump(
          tester,
          names: names,
          lateEntries: true,
          size: const Size(2520, 1350),
        );
        await tester.scrollUntilVisible(
          _entryNamed(name),
          200,
          scrollable: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(_entryNamed(name));
        await tester.pump();
        // The entry arrives while the morph waits for it.
        await tester.pump(const Duration(milliseconds: 60));
        await _untilStarted(tester);
        await tester.pump(launchMorphDuration);
        _expectLanded(tester, name);
        await tester.pumpAndSettle();
      });
    }
  });

  testWidgets('a launched entry detaches: a new one fades in at its place', (
    tester,
  ) async {
    Future<void> pumpEntry(Object? reappearing) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 150,
            child: AppEntry(
              desktopEntry: _entry('Alpha'),
              onLaunch: (_, _) {},
              reappearing: reappearing,
            ),
          ),
        ),
      ),
    );
    double opacity() => tester
        .widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(AppEntry),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    await pumpEntry(null);
    expect(opacity(), 1);

    final launch = Object();
    await pumpEntry(launch);
    // Hidden while the launched item leaves its place…
    expect(opacity(), 0);
    await tester.pump(launchMorphDuration * 0.3);
    expect(opacity(), 0);
    // …then back in, by the end of the morph.
    await tester.pump(launchMorphDuration * 0.3);
    expect(opacity(), inExclusiveRange(0, 1));
    await tester.pump(launchMorphDuration * 0.4);
    expect(opacity(), 1);

    // The same launch, rebuilt, does not replay; the next one does.
    await pumpEntry(launch);
    expect(opacity(), 1);
    await pumpEntry(Object());
    expect(opacity(), 0);
    await tester.pumpAndSettle();
  });

  testWidgets("only the launched section's entry detaches", (tester) async {
    final searchFocusNode = FocusNode();
    addTearDown(searchFocusNode.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDrawerDesktopEntriesProvider.overrideWith(
            (ref) async => [_entry('Alpha'), _entry('Beta')],
          ),
          appDrawerFrequentDesktopEntriesProvider.overrideWithValue(
            AsyncData([_entry('Alpha')]),
          ),
          iconFileFromQueryProvider.overrideWith((ref, query) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => AppDrawer(
                searchFocusNode: searchFocusNode,
                // Registers the morph as the launcher does.
                onSelect: (entry, origin) async => ref
                    .read(launchMorphsProvider.notifier)
                    .start(
                      const PersistentWindowId('tile'),
                      LaunchMorphRequest(
                        entry: entry,
                        origin: origin!,
                        launcherRect: Rect.zero,
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double opacityIn(Type section) => tester
        .widget<FadeTransition>(
          find
              .descendant(
                of: find.descendant(
                  of: find.byType(section),
                  matching: _entryNamed('Alpha'),
                ),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    await tester.tap(
      find.descendant(of: find.byType(AppRow), matching: _entryNamed('Alpha')),
    );
    await tester.pump();

    // The row's Alpha left; the list's stays.
    expect(opacityIn(AppRow), 0);
    expect(opacityIn(AppGridSliver), 1);
    await tester.pumpAndSettle();
  });
}
