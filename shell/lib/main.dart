import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/display.widget.dart';
import 'package:shell/manager/surface/surface.manager.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';
import 'package:shell/manager/window/window.manager.dart';
import 'package:shell/shared/util/root_overlay.provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  // debugRepaintRainbowEnabled = true;
  // debugPrintGestureArenaDiagnostics = true;
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

  SchedulerBinding.instance.addPostFrameCallback((_) {
    //platformApi.startupComplete();
  });

  container
    ..read(waylandManagerProvider)
    ..read(surfaceManagerProvider)
    ..read(windowManagerProvider);
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const Veshell(),
    ),
  );
}

class Veshell extends ConsumerWidget {
  const Veshell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (
            BuildContext context,
            WidgetRef ref,
            Widget? child,
          ) {
            return Stack(
              children: [
                const DisplayWidget(),
                Overlay(
                  key: ref.watch(rootOverlayKeyProvider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
