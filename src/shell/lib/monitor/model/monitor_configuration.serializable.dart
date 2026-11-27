import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';

part 'monitor_configuration.serializable.freezed.dart';
part 'monitor_configuration.serializable.g.dart';

enum ScreenDisplayMode { splitHorizontal, splitVertical }

/// Flutter-only shell layout for one monitor: its screens and split direction.
///
/// Persisted by `MonitorConfigurationState`; never written to the Rust-side
/// `monitor/<connector>.json`. See `docs/specifications/monitor.md` (section
/// "State ownership").
@freezed
abstract class MonitorConfiguration with _$MonitorConfiguration {
  /// Factory
  factory MonitorConfiguration({
    required IList<ScreenConfiguration> screenList,
    required ScreenDisplayMode displayMode,

    /// The flex of each screen the user last set by dragging a divider, by
    /// screen count (as a string: JSON object keys are strings). Adding or
    /// removing a screen restores the split saved for the new count.
    @Default(IMapConst<String, IList<int>>({}))
    IMap<String, IList<int>> flexForScreenCount,
  }) = _MonitorConfiguration;
  MonitorConfiguration._();
  factory MonitorConfiguration.fromJson(Map<String, dynamic> json) =>
      _$MonitorConfigurationFromJson(json);
}
