import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_application_launcher/app_drawer/app_grid.dart';
import 'package:shell/manager/application/app_drawer.provider.dart';

part 'app_drawer.provider.g.dart';

@Riverpod(keepAlive: true)
class AppDrawerVisible extends _$AppDrawerVisible {
  @override
  bool build() => false;

  @override
  set state(bool value) {
    super.state = value;
  }

  void update(bool Function(bool) callback) {
    super.state = callback(state);
  }
}

@Riverpod(keepAlive: true)
List<AppEntry> appEntryWidget(AppEntryWidgetRef ref) {
  final desktopEntries = ref.watch(appDrawerFilteredDesktopEntriesProvider);
  return desktopEntries.maybeWhen(
    skipLoadingOnReload: true,
    data: (List<LocalizedDesktopEntry> desktopEntries) => desktopEntries
        .map((desktopEntry) => AppEntry(desktopEntry: desktopEntry))
        .toList(),
    orElse: () => [],
  );
}
