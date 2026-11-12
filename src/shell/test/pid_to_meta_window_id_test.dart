import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/pid_to_meta_window_id.dart';
import 'package:shell/platform/model/event/meta_window_created/meta_window_created.serializable.dart';

const _pid = 4242;

MetaWindowCreatedMessage _created(String id, int surfaceId) =>
    MetaWindowCreatedMessage(
      id: id,
      pid: _pid,
      mapped: true,
      surfaceId: surfaceId,
      needDecoration: true,
      gameModeActivated: false,
      scaleRatio: 1,
      appId: 'org.example.App',
    );

/// What notification routing does with a sender's pid.
String? _windowForPid(ProviderContainer container) {
  final ref = container.read(_refProvider);
  final metaWindowId = ref.readMetaWindowIdForPid(_pid);
  return metaWindowId == null ? null : ref.readMetaWindow(metaWindowId).id;
}

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late ProviderContainer container;
  final views = <String, ProviderSubscription<Object?>>{};

  setUp(() {
    container = ProviderContainer(
      overrides: [
        localizedDesktopEntryForIdProvider.overrideWith2(
          (_) => _NoDesktopEntry(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> open(String id, int surfaceId) async {
    // A live window is watched by the UI showing it.
    views[id] = container.listen(metaWindowStateProvider(id), (_, _) {});
    await container
        .read(metaWindowStateProvider(id).notifier)
        .create(_created(id, surfaceId));
  }

  /// The compositor destroys the window and the UI showing it unmounts.
  Future<void> close(String id) async {
    container.read(metaWindowStateProvider(id).notifier).destroy();
    views.remove(id)!.close();
    await Future<void>.delayed(Duration.zero);
  }

  test('a pid maps to its window', () async {
    await open('a', 1);
    expect(_windowForPid(container), 'a');
  });

  test('closing one window of a pid falls back to a live one', () async {
    await open('a', 1);
    await open('b', 2);

    await close('b');

    expect(_windowForPid(container), 'a');
  });

  test('closing the last window of a pid forgets it', () async {
    await open('a', 1);

    await close('a');

    expect(_windowForPid(container), isNull);
  });
}

class _NoDesktopEntry extends LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => null;
}
