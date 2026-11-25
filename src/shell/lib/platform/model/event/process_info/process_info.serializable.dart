import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'process_info.serializable.freezed.dart';
part 'process_info.serializable.g.dart';

/// Process-level facts read from `/proc` for a surface client pid.
///
/// Delivered keyed by pid rather than duplicated on every window: the cgroup
/// and the raw Flatpak/Snap/binary identities belong to the process. Snapshot
/// at window creation, refreshed when the pid changes, when the window is
/// mapped, when its title changes, and on demand while a tile is displayed.
@freezed
abstract class ProcessInfoMessage
    with _$ProcessInfoMessage
    implements PlatformMessage {
  /// Factory
  factory ProcessInfoMessage({
    required int pid,
    String? cgroup,
    String? flatpakId,
    String? snapId,
    String? binaryName,
    @Default(<String>[]) List<String> cmdline,
    String? cwd,
    String? exe,
    TerminalInfoMessage? terminal,
    WineInfoMessage? wine,
  }) = _ProcessInfoMessage;

  factory ProcessInfoMessage.fromJson(Map<String, dynamic> json) =>
      _$ProcessInfoMessageFromJson(json);
}

/// Terminal-specific process context.
@freezed
abstract class TerminalInfoMessage with _$TerminalInfoMessage {
  factory TerminalInfoMessage({
    ProcessDescriptorMessage? shell,
    ProcessDescriptorMessage? foreground,
  }) = _TerminalInfoMessage;

  factory TerminalInfoMessage.fromJson(Map<String, dynamic> json) =>
      _$TerminalInfoMessageFromJson(json);
}

/// One process in a terminal's shell/foreground chain.
@freezed
abstract class ProcessDescriptorMessage with _$ProcessDescriptorMessage {
  factory ProcessDescriptorMessage({
    required int pid,
    @Default(<String>[]) List<String> cmdline,
    String? exe,
    String? cwd,
  }) = _ProcessDescriptorMessage;

  factory ProcessDescriptorMessage.fromJson(Map<String, dynamic> json) =>
      _$ProcessDescriptorMessageFromJson(json);
}

/// Wine/Proton context of a process, read from its initial environment.
///
/// Wine rewrites argv to the Windows command line, so for these processes
/// `cmdline` names a `.exe` path no Linux launcher can run; this says how the
/// program was actually started.
@freezed
abstract class WineInfoMessage with _$WineInfoMessage {
  const WineInfoMessage._();

  factory WineInfoMessage({
    /// `WINEPREFIX`, when set.
    String? prefix,

    /// The Steam app id the game was launched as, present only when Steam
    /// itself launched it (not for Proton run by umu-launcher, which sets the
    /// same Steam variables).
    String? steamAppId,

    /// `STEAM_COMPAT_DATA_PATH`: set whenever Proton runs, by Steam or by
    /// umu-launcher.
    String? compatDataPath,

    /// `STEAM_COMPAT_TOOL_PATHS`: the Proton install, then the runtime(s).
    @Default(<String>[]) List<String> compatToolPaths,

    /// The Wine configuration variables the process started with (`WINE*`,
    /// `DXVK_*`, `VKD3D_*`, `STAGING_*`), without Wine's session variables.
    @Default(<String, String>{}) Map<String, String> environment,
  }) = _WineInfoMessage;

  factory WineInfoMessage.fromJson(Map<String, dynamic> json) =>
      _$WineInfoMessageFromJson(json);

  /// Whether the process runs on Proton (launched by Steam or umu-launcher)
  /// rather than a plain Wine.
  bool get isProton => compatDataPath != null;
}
