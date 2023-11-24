import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'surface_ids.provider.g.dart';

@Riverpod(keepAlive: true)
class SurfaceIds extends _$SurfaceIds {
  @override
  ISet<int> build() {
    return ISet();
  }

  // Make it public. Was protected in the superclass.
  @override
  set state(ISet<int> value) {
    super.state = value;
  }

  void update(ISet<int> Function(ISet<int>) callback) {
    super.state = callback(state);
  }
}
