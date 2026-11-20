import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

part 'optimized_overview_setting.g.dart';

const optimizedOverviewPath = 'theme.optimizedOverview';

/// Whether the overview trades live motion for an idle GPU
/// (`theme.optimizedOverview`). On unless the value is `false`.
///
/// While on, the monitoring sparklines step to each new sample instead of
/// sliding, and the settled frost behind the overview is baked into an image
/// instead of being re-applied to the whole screen on every frame.
@riverpod
bool optimizedOverviewSetting(Ref ref) =>
    ref.watch(jsonValueByPathProvider(optimizedOverviewPath)) != false;
