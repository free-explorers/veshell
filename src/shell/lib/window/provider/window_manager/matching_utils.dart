import 'package:shell/window/model/matching_info.serializable.dart';
import 'package:shell/window/model/window_base.dart';

/// Checks if `found` is equal to `desired` and returns the appropriate cost.
/// If desired is not given (null) then `skipCost` is returned.
/// If `found` is equal to `desired` then `0` is returned, otherwise `mismatchCost`.
int matchingCost<T>(T desired, T found, int mismatchCost, int skipCost) {
  if (desired != null) {
    return found == desired ? 0 : mismatchCost;
  } else {
    return skipCost;
  }
}

const INF_COST = 100000;

/// After a meta window has been associated with an MsWindow, we allow this association to change
/// for a small amount of time.
///
/// This is to allow for the case where the window title changes and another association becomes much
/// more desirable. This happens often when opening text editors that restore the previously opened documents.
/// In those cases multiple windows may open with initially identical window titles, but once the documents
/// have loaded the window titles change and we might be able to make better associations.
const MAX_WINDOW_REASSOCIATION_TIME_MS = 3000;

/// Windows that are created, but then have their metawindow removed from them very quickly are not desirable.
/// So we kill those windows when that happens.
const WINDOW_RECENTLY_CREATED_TIME_MS = 2000;

/// Cost for associating the the given metaWindow to the msWindow.
///
/// windowInfo are the matching details for the meta window, for example its window title.
///
/// A higher returned cost means the match is less desirable.
int windowMatchingCost(
  MatchingInfo metaWindowMatchInfo,
  MatchingInfo windowMatchInfo,
  Window window,
) {
  var cost = 0;
  // The wmClass *must* match if specified
  cost += matchingCost(
    windowMatchInfo.windowClass,
    metaWindowMatchInfo.windowClass,
    INF_COST,
    1,
  );
  cost += matchingCost(windowMatchInfo.title, metaWindowMatchInfo.title, 50, 1);
  cost += matchingCost(
      windowMatchInfo.startupId, metaWindowMatchInfo.startupId, 1, 1);

  cost += matchingCost(windowMatchInfo.pid, metaWindowMatchInfo.pid, 1, 1);

  cost += windowMatchInfo.waitingForAppSince != null
      ? 100 -
          (DateTime.now()
                      .difference(windowMatchInfo.waitingForAppSince!)
                      .inMilliseconds
                      .clamp(
                        0,
                        1000,
                      ) /
                  100)
              .round() // Clamp the difference to be between 0 and 1000 milliseconds
      : 200;

  return cost;
}
