import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/provider/meta_window_manager.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/widget/monitor.dart';
import 'package:shell/notification/provider/notification_manager.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_client.dart';
import 'package:shell/platform/model/request/get_environment_variables/get_environment_variables.serializable.dart';
import 'package:shell/platform/model/request/get_monitor_layout/get_monitor_layout.serializable.dart';
import 'package:shell/platform/model/request/shell_ready/shell_ready.serializable.dart';
import 'package:shell/platform/provider/environment_variables.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/polkit/provider/authentication_agent.dart';
import 'package:shell/screen/provider/screen_manager.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_audio.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_server_info.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_sink_list.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_source_list.dart';
import 'package:shell/shared/util/logger.dart';
import 'package:shell/shortcut_manager/widget/shortcut_manager.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';

void main() async {
  configureLogs();
  // debugRepaintRainbowEnabled = true;
  // debugPrintGestureArenaDiagnostics = true;
  WidgetsFlutterBinding.ensureInitialized();

  FocusManager.instance.addListener(() {
    focusLog.info(
      'FocusManager.instance.primaryFocus ${FocusManager.instance.primaryFocus}',
    );
  });
  runWidget(
    const ProviderScope(
      child: _EagerInitialization(child: Veshell()),
    ),
  );
}

final globalVeshellKey = GlobalKey();

class Veshell extends HookConsumerWidget {
  const Veshell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = RendererBinding.instance.platformDispatcher.views
        .where(
          (view) =>
              view != RendererBinding.instance.platformDispatcher.implicitView,
        )
        .toList();

    useEffect(
      () {
        ref.read(platformManagerProvider.notifier)
          ..request(
            GetEnvironmentVariablesRequest(
              message: GetEnvironmentVariablesMessage(),
            ),
          )
          ..request(
            GetMonitorLayoutRequest(
              message: GetMonitorLayoutMessage(),
            ),
          )
          ..request(const ShellReadyRequest());
        return null;
      },
      [],
    );

    return VeshellShortcutManager(
      child: ViewCollection(
        views: views
            .map(
              (view) => View(
                view: view,
                child: MonitorWidget(
                  viewId: view.viewId,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _EagerInitialization extends ConsumerWidget {
  const _EagerInitialization({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize providers by watching them.
    // By using "watch", the provider will stay alive and not be disposed.
    final results = [
      ref.watch(persistentStorageStateProvider),
      ref.watch(pulseClientProvider),
      ref.watch(pulseServerInfoProvider),
      ref.watch(pulseSinkListProvider),
      ref.watch(pulseSourceListProvider),
      ref.watch(upowerClientProvider),
    ];

    ref.watch(connectedMonitorListProvider);

    // Handle error states and loading states
    if (results.any(
      (element) => element.isLoading,
    )) {
      return InitializationStatus(
        asyncValue: const AsyncLoading(),
        child: child,
      );
    } else if (results.any(
      (element) => element.hasError,
    )) {
      return InitializationStatus(
        asyncValue: AsyncError(
          Error(),
          StackTrace.current,
        ),
        child: child,
      );
    }

    ref
      ..watch(platformManagerProvider)
      ..watch(environmentVariablesProvider)
      ..watch(surfaceManagerProvider)
      ..watch(screenManagerProvider)
      ..watch(windowManagerProvider)
      ..watch(metaWindowManagerProvider)
      ..watch(polkitAuthenticationAgentStateProvider)
      ..watch(matchingEngineProvider)
      ..watch(notificationManagerProvider);

    return InitializationStatus(
      asyncValue: const AsyncData(true),
      child: child,
    );
  }
}

class InitializationStatus extends InheritedWidget {
  const InitializationStatus({
    required this.asyncValue,
    required super.child,
    super.key,
  });

  final AsyncValue<bool> asyncValue;

  static AsyncValue<bool> of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<InitializationStatus>();
    if (provider == null) {
      throw FlutterError('InitializationStatus not found in the widget tree');
    }
    return provider.asyncValue;
  }

  @override
  bool updateShouldNotify(InitializationStatus oldWidget) =>
      asyncValue != oldWidget.asyncValue;
}
