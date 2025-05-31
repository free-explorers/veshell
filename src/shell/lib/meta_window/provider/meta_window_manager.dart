import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_popup_state.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/meta_window/provider/meta_window_window_map.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/dialog_window_state.dart';
import 'package:shell/window/provider/ephemeral_window_state.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:shell/window/provider/window_provider.mixin.dart';

part 'meta_window_manager.g.dart';

@riverpod
class MetaWindowManager extends _$MetaWindowManager {
  final Map<MetaWindowId, ProviderSubscription<bool>> _mappedSubscriptions = {};
  @override
  ISet<MetaWindowId> build() {
    ref.watch(platformManagerProvider).listen((next) {
      if (next case final MetaWindowCreatedEvent event) {
        onNewMetaWindow(event);
      }
      if (next case final MetaWindowPatchEvent event) {
        ref.read(metaWindowStateProvider(event.message.id).notifier).patch(
              event.message,
              propagate: false,
            );
      }
      if (next case final MetaWindowRemovedEvent event) {
        onMetaWindowRemoved(event.message.id);
      }
      if (next case final MetaPopupCreatedEvent event) {
        onNewMetaPopup(event);
      }
      if (next case final MetaPopupPatchEvent event) {
        ref.read(metaPopupStateProvider(event.message.id).notifier).applyPatch(
              event.message,
            );
      }
      if (next case final MetaPopupRemovedEvent event) {
        onMetaPopupRemoved(event.message.id);
      }
    });

    return <MetaWindowId>{}.lock;
  }

  Future<void> onNewMetaWindow(MetaWindowCreatedEvent event) async {
    final metaWindowId = event.message.id;
    await ref.read(metaWindowStateProvider(metaWindowId).notifier).create(
          event.message,
        );

    _mappedSubscriptions[metaWindowId] = ref.listen(
      metaWindowStateProvider(metaWindowId).select(
        (value) => value.mapped,
      ),
      (previouslyMapped, isMapped) {
        if (previouslyMapped != isMapped && isMapped == true) {
          onMetaWindowMapped(metaWindowId);
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

    if (ref.read(metaWindowWindowMapProvider).get(id) != null) {
      return;
    }

    if (metaWindow.parent != null) {
      final parentWindowId =
          ref.read(metaWindowWindowMapProvider).get(metaWindow.parent!);
      if (parentWindowId == null) {
        // try again after a short delay because the parent window might not be mapped yet
        if (retryCount < 10) {
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
  }

  void onMetaWindowRemoved(MetaWindowId id) {
    final windowId = ref.read(metaWindowWindowMapProvider).get(id);
    if (windowId != null) {
      (switch (windowId) {
        PersistentWindowId() =>
          ref.read(persistentWindowStateProvider(windowId).notifier),
        DialogWindowId() =>
          ref.read(dialogWindowStateProvider(windowId).notifier),
        EphemeralWindowId() =>
          ref.read(ephemeralWindowStateProvider(windowId).notifier),
      } as WindowProviderMixin)
          .onMetaWindowRemoved(id);
    }
    _mappedSubscriptions.remove(id)?.close();
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
