import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/wayland/model/event/wayland_event.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

part 'meta_window_manager.g.dart';

@Riverpod(keepAlive: true)
class MetaWindowManager extends _$MetaWindowManager {
  final Map<MetaWindowId, ProviderSubscription<bool>> _mappedSubscriptions = {};
  @override
  ISet<MetaWindowId> build() {
    ref.listen(waylandManagerProvider, (_, next) {
      if (next case AsyncData(value: final MetaWindowCreatedEvent event)) {
        onNewMetaWindow(event);
      }
      if (next case AsyncData(value: final MetaWindowPatchEvent event)) {
        ref.read(metaWindowStateProvider(event.message.id).notifier).patch(
              event.message,
              propagate: false,
            );
      }
      if (next case AsyncData(value: final MetaWindowRemovedEvent event)) {
        onMetaWindowRemoved(event.message.id);
      }
      if (next case AsyncData(value: final MetaPopupCreatedEvent event)) {
        onNewMetaPopup(event);
      }
      if (next case AsyncData(value: final MetaPopupPatchEvent event)) {
        ref.read(metaPopupStateProvider(event.message.id).notifier).applyPatch(
              event.message,
            );
      }
      if (next case AsyncData(value: final MetaPopupRemovedEvent event)) {
        onMetaPopupRemoved(event.message.id);
      }
    });

    return <MetaWindowId>{}.lock;
  }

  Future<void> onNewMetaWindow(MetaWindowCreatedEvent event) async {
    print('New meta window: ${event.message.id}');
    final metaWindowId = event.message.id;
    await ref.read(metaWindowStateProvider(metaWindowId).notifier).create(
          event.message,
        );

    _mappedSubscriptions[metaWindowId] = ref.listen(
      metaWindowStateProvider(metaWindowId).select(
        (value) => value.mapped,
      ),
      (previous, next) {
        if (next) {
          onMetaWindowMapped(metaWindowId);
        } else {
          onMetaWindowUnmapped(metaWindowId);
        }
      },
    );

    state = state.add(metaWindowId);

    if (event.message.mapped) {
      onMetaWindowMapped(metaWindowId);
    }
  }

  void onMetaWindowMapped(MetaWindowId id, {int retryCount = 0}) {
    final metaWindow = ref.read(metaWindowStateProvider(id));

    if (metaWindow.parent != null) {
      final parentWindowId =
          ref.read(metaWindowWindowMapProvider).get(metaWindow.parent!);
      if (parentWindowId == null) {
        // try again after a short delay because the parent window might not be mapped yet
        if (retryCount > 10) {
          Future.delayed(const Duration(milliseconds: 100), () {
            onMetaWindowMapped(id, retryCount: retryCount + 1);
          });
        }
        return;
      }
      ref
          .read(windowManagerProvider.notifier)
          .createDialogWindowForMetaWindow(metaWindow.id, parentWindowId);
      return;
    }

    ref.read(matchingEngineProvider.notifier).addMetaWindow(id);

    print('MetaWindowMapped: $id');
  }

  void onMetaWindowUnmapped(MetaWindowId id) {
    ref.read(windowManagerProvider.notifier).onMetaWindowUnmapped(id);
  }

  void onMetaWindowRemoved(String id) {
    _mappedSubscriptions.remove(id)?.close();
    onMetaWindowUnmapped(id);
    ref.read(metaWindowStateProvider(id).notifier).destroy();
    state = state.remove(id);
  }

  void onNewMetaPopup(MetaPopupCreatedEvent event) {
    ref
        .read(metaPopupStateProvider(event.message.id).notifier)
        .create(event.message);
  }

  void onMetaPopupRemoved(String id) {
    ref.read(metaPopupStateProvider(id).notifier).destroy();
  }
}
