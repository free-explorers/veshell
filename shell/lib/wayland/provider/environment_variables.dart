import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/event/wayland_event.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'environment_variables.g.dart';

@Riverpod(keepAlive: true)
class EnvironmentVariables extends _$EnvironmentVariables {
  @override
  IMap<String, String> build() {
    ref.listen(waylandManagerProvider, (_, next) {
      switch (next) {
        case AsyncData(value: final SetEnvironmentVariablesEvent event):
          _set(event.message.environmentVariables);
      }
    });

    return IMap();
  }

  void _set(IMap<String, String?> environmentVariables) {
    for (final entry in environmentVariables.entries) {
      final MapEntry(key: key, value: value) = entry;
      if (value != null) {
        state = state.add(key, value);
      } else {
        state = state.remove(key);
      }
    }
  }
}
