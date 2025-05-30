import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'overview.freezed.dart';

@freezed
abstract class Overview with _$Overview {
  factory Overview({
    required ScreenId screenId,
    required IList<EphemeralWindowId> windowList,
    required bool isDisplayed,
  }) = _Overview;
}
