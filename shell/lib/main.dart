import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/widget/display.dart';
import 'package:shell/monitor/provider/monitor_list.dart';
import 'package:shell/screen/provider/screen_list.dart';
import 'package:shell/shared/provider/persistent_json_by_folder.dart';
import 'package:shell/shared/provider/root_overlay.dart';
import 'package:shell/theme/provider/theme.manager.dart';
import 'package:shell/wayland/model/request/get_environment_variables/get_environment_variables.serializable.dart';
import 'package:shell/wayland/model/request/get_monitor_layout/get_monitor_layout.serializable.dart';
import 'package:shell/wayland/model/request/shell_ready/shell_ready.serializable.dart';
import 'package:shell/wayland/provider/environment_variables.dart';
import 'package:shell/wayland/provider/surface.manager.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';
import 'package:shell/window/provider/window_manager/window_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  // debugRepaintRainbowEnabled = true;
  // debugPrintGestureArenaDiagnostics = true;
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

  container
    ..read(environmentVariablesProvider)
    ..read(waylandManagerProvider)
    ..read(surfaceManagerProvider);

  SchedulerBinding.instance.addPostFrameCallback((_) {
    container.read(waylandManagerProvider.notifier)
      ..request(
        GetEnvironmentVariablesRequest(
          message: GetEnvironmentVariablesMessage(),
        ),
      )
      ..request(
        GetMonitorLayoutRequest(
          message: GetMonitorLayoutMessage(),
        ),
      );
  });

  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const Veshell(),
    ),
  );
}

class _EagerInitialization extends ConsumerWidget {
  const _EagerInitialization({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize providers by watching them.
    // By using "watch", the provider will stay alive and not be disposed.
    final result = ref.watch(persistentJsonByFolderProvider);
    ref.watch(monitorListProvider);
    // Handle error states and loading states
    if (result.isLoading) {
      return const CircularProgressIndicator();
    } else if (result.hasError) {
      print(result.asError);
      return Row(
        children: [
          Text(result.asError.toString()),
        ],
      );
    }

    ref
      ..watch(screenListProvider)
      ..watch(windowManagerProvider);

    return child;
  }
}

class Veshell extends ConsumerWidget {
  const Veshell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return MaterialApp(
      theme: theme,
      home: _EagerInitialization(
        child: Scaffold(
          body: HookConsumer(
            builder: (
              BuildContext context,
              WidgetRef ref,
              Widget? child,
            ) {
              useEffect(() {
                ref
                    .read(waylandManagerProvider.notifier)
                    .request(const ShellReadyRequest());
                return null;
              });
              return Stack(
                children: [
                  const Positioned.fill(child: DisplayWidget()),
                  Overlay(
                    key: ref.watch(rootOverlayKeyProvider),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
