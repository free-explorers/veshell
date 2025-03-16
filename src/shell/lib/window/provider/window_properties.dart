import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/pid_to_surface_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/window_manager/matching_engine.dart';

part 'window_properties.g.dart';

const SNAP_SECURITY_LABEL_PREFIX = 'snap.';

@Riverpod(keepAlive: true)
class WindowPropertiesState extends _$WindowPropertiesState {
  @override
  WindowProperties build(SurfaceId surfaceId) {
    listenSelf(
      (previous, next) {
        if (previous != next) {
          ref.read(matchingEngineProvider.notifier).checkMatching();
        }
      },
    );
    return const WindowProperties(
      appId: '',
    );
  }

  void setAppId(String appId) {
    var realAppId = appId;
    if (state.pid != null && state.pid != 0) {
      realAppId = _determineDesktopFileIdFromPid(state.pid!) ?? appId;
    }
    state = state.copyWith(appId: realAppId);
  }

  void setTitle(String? title) {
    state = state.copyWith(title: title);
  }

  void setPid(int pid) {
    ref.read(pidToSurfaceIdProvider.notifier).setPid(pid, surfaceId);

    state = state.copyWith(
      pid: pid,
    );

    setAppId(state.appId);
  }

  void setProperties({
    String? appId,
    int? pid,
    String? title,
    String? windowClass,
    String? startupId,
  }) {
    final currentPid = pid ?? state.pid;
    final pidExist = currentPid != null && currentPid != 0;
    if (pidExist) {
      ref.read(pidToSurfaceIdProvider.notifier).setPid(currentPid, surfaceId);
    }

    final realAppId = pidExist
        ? _determineDesktopFileIdFromPid(currentPid) ?? appId ?? state.appId
        : appId ?? state.appId;

    state = state.copyWith(
      appId: realAppId,
      pid: pid ?? state.pid,
      title: title,
      windowClass: windowClass,
      startupId: startupId,
    );
  }

  String? _determineDesktopFileIdFromPid(int pid) {
    final (isFlatpack, flatpackId) = _getFlatpackIdFromPid(pid);

    if (isFlatpack) {
      return flatpackId!;
    }

    final (isSnap, snapId) = _getSnapIdFromPid(pid);
    if (isSnap) {
      return snapId!;
    }

    return null;
  }

  (bool, String?) _getFlatpackIdFromPid(int pid) {
    if (pid == 0) {
      return (false, null);
    }
    final infoFilename = '/proc/$pid/root/.flatpak-info';
    final infoFile = File(infoFilename);

    if (!infoFile.existsSync()) {
      return (false, null);
    }
    String? appId;

    final lines = infoFile.readAsLinesSync();
    for (final line in lines) {
      if (line.startsWith('name=')) {
        appId = line.substring(5); // Extract the value after 'name='
        break;
      }
    }
    if (appId == null) {
      return (false, null);
    }
    return (true, appId);
  }

  (bool, String?) _getSnapIdFromPid(int pid) {
    if (pid == 0) {
      return (false, null);
    }

    final securityLabelFilename = '/proc/$pid/attr/current';
    final securityLabelFile = File(securityLabelFilename);

    if (!securityLabelFile.existsSync()) {
      return (false, null);
    }

    try {
      var securityLabelContents = securityLabelFile.readAsStringSync();

      // Remove the SNAP_SECURITY_LABEL_PREFIX from the contents
      securityLabelContents =
          securityLabelContents.substring(SNAP_SECURITY_LABEL_PREFIX.length);

      // Find the end of the relevant part of the contents
      final contentsEndIndex = securityLabelContents.indexOf(' ');
      if (contentsEndIndex != -1) {
        securityLabelContents =
            securityLabelContents.substring(0, contentsEndIndex);
      }

      return (true, securityLabelContents.replaceAll('.', '_'));
    } on FileSystemException {
      return (false, null);
    }
  }
}
