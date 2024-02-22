import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/shared/persistence/persistable_model.mixin.dart';

part 'screen_configuration.serializable.freezed.dart';
part 'screen_configuration.serializable.g.dart';

enum ScreenDisplayMode {
  splitHorizontal,
  splitVertical,
}

///
@freezed
class ScreenConfiguration
    with _$ScreenConfiguration
    implements PersistableModel {
  /// Factory
  factory ScreenConfiguration({
    required IList<ScreenId> screenList,
    required ScreenDisplayMode displayMode,
  }) = _ScreenConfiguration;
  ScreenConfiguration._();
  factory ScreenConfiguration.fromJson(Map<String, dynamic> json) =>
      _$ScreenConfigurationFromJson(json);
}
