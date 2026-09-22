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

/// Cost for associating the the given metaWindow to the msWindow.
///
/// windowInfo are the matching details for the meta window, for example its window title.
///
/// A higher returned cost means the match is less desirable.
///
/// The cost model deliberately weights identity promises that indicate *the
/// same application instance* over cosmetic metadata. Rule of thumb, when a
/// property is set on the candidate side:
///
/// | Signal            | Match | Mismatch | Not set on candidate |
/// |-------------------|-------|----------|----------------------|
/// | windowClass       | 0     | INF_COST (hard identity, e.g. X11 class) | 1 |
/// | title             | 0     | 50       | 1                     |
/// | startupId         | 0     | 1        | 1                     |
/// | pid               | 0     | 1        | 1                     |
/// | waiting           | 100 → 90 over the first second since the app was launched | 200 (not waiting) |
///
/// Reading the table:
///
/// - `INF_COST` on class means: when the *candidate window* advertises a
///   class, the native window must carry it; class mismatch is a
///   veto, everything else is a tie-break.
/// - A placeholder launched *seconds ago* (the "waiting" state set by
///   `waitForSurface`) is the **gather** signal: while it is armed the whole
///   launch burst is collected onto the clicked tile, which then dispatches
///   the windows whose title matches a sibling better. It is cleared at the
///   burst settle and is never a reason to *keep* a window the tile does not
///   fit.
/// - `pid` matches are almost useless as evidence (the placeholder records
///   its launcher's pid; multi-process applications report a different one),
///   hence the negligible 1.
///
/// Worked example — two placeholders for the same desktop entry, none
/// waiting, native window title "Document — Code":
///
/// - placeholder with desktop-entry name "Code - OSS" → 1 + 50 + 1 + 1 + 200
///   = 253 (class/title/startup/pid skips+mismatch, not waiting)
/// - placeholder renamed "Document — Code" via custom title → 203
/// → the custom-title placeholder wins, without any provenance involved.
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
    windowMatchInfo.startupId,
    metaWindowMatchInfo.startupId,
    1,
    1,
  );

  cost += matchingCost(windowMatchInfo.pid, metaWindowMatchInfo.pid, 1, 1);

  cost += windowMatchInfo.waitingForAppSince != null
      ? 100 -
            (DateTime.now()
                        .difference(windowMatchInfo.waitingForAppSince!)
                        .inMilliseconds
                        .clamp(0, 1000) /
                    100)
                .round() // Clamp the difference to be between 0 and 1000 milliseconds
      : 200;

  return cost;
}
