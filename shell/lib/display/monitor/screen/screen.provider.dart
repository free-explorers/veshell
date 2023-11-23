import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/monitor/monitor.provider.dart';
import 'package:shell/display/monitor/screen/screen.model.dart';

part 'screen.provider.g.dart';

/// Provide the current Screen to all his childrens
@Riverpod(dependencies: [])
Screen currentScreen(CurrentScreenRef ref) {
  // This provider is instentatied in Children Scope
  throw Exception('Provider was not initialized');
}

/// Provide list of plugged Screens
@Riverpod(dependencies: [currentMonitor])
List<Screen> screenList(ScreenListRef ref) {
  final monitor = ref.watch(currentMonitorProvider);
  return [Screen(surface: monitor.surface)];
}
