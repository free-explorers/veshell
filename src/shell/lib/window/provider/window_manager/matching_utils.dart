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

/// Maximum cost for a title mismatch.
///
/// A title mismatch is graded down when the two titles share a long contiguous
/// chunk, so a title that only changed in its volatile parts (an unread count,
/// a collapsed page title) scores far below an unrelated title. Bounded by the
/// old flat mismatch value, so the field keeps its weight against the other
/// signals.
const _titleMismatchCost = 50;

String _normalizeTitle(String title) =>
    title.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// Longest run of identical characters between [a] and [b]. Both sides are
/// normalized by the caller.
int _longestCommonSubstringLength(String a, String b) {
  if (a.isEmpty || b.isEmpty) {
    return 0;
  }
  var previous = List<int>.filled(b.length + 1, 0);
  var longest = 0;
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    for (var j = 1; j <= b.length; j++) {
      if (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1)) {
        current[j] = previous[j - 1] + 1;
        if (current[j] > longest) {
          longest = current[j];
        }
      }
    }
    previous = current;
  }
  return longest;
}

/// Cost for matching the native window's [windowTitle] against a candidate's
/// stored [storedTitle].
///
/// Exact match is free, no stored title is a skip (1), and everything else is
/// graded in `[1, _titleMismatchCost]` by the longest common substring relative
/// to the *shorter* title. A near miss (a title that changed in its volatile
/// parts, or one title contained in the other) therefore scores well under a
/// total mismatch, while a short or generic title stays at the flat mismatch so
/// it cannot win on a shared app suffix alone.
int titleMatchingCost(String? storedTitle, String? windowTitle) {
  if (storedTitle == null) {
    return 1;
  }
  final stored = _normalizeTitle(storedTitle);
  final window = _normalizeTitle(windowTitle ?? '');
  if (stored == window) {
    return 0;
  }
  if (stored.isEmpty || window.isEmpty) {
    return _titleMismatchCost;
  }
  final overlap = _longestCommonSubstringLength(stored, window);
  final shortest =
      stored.length < window.length ? stored.length : window.length;
  if (shortest < 8 || overlap < 4) {
    return _titleMismatchCost;
  }
  final coverage = overlap / shortest;
  return (_titleMismatchCost * (1 - coverage))
      .round()
      .clamp(1, _titleMismatchCost);
}

/// After a meta window has been associated with an MsWindow, we allow this association to change
/// for a small amount of time.
///
/// This is to allow for the case where the window title changes and another association becomes much
/// more desirable. This happens often when opening text editors that restore the previously opened documents.
/// In those cases multiple windows may open with initially identical window titles, but once the documents
/// have loaded the window titles change and we might be able to make better associations.
const MAX_WINDOW_REASSOCIATION_TIME_MS = 3000;

/// Upper bound on how long a launch burst keeps gathering while the only
/// windows it has produced are fixed-size (a splash or updater).
///
/// Applications with a splash/updater map a transient fixed-size window first
/// and the real (resizable) window hundreds of milliseconds later. Settling on
/// the helper alone would make the real window look like a *further opening*
/// and turn it into a dialog. The gather is therefore deferred until a
/// resizable window arrives, but only up to this bound, so a genuinely
/// fixed-size final surface still settles as the tile's own window. Chosen
/// above the observed GIMP splash gap (~1.3 s) with headroom, below
/// [MAX_WINDOW_REASSOCIATION_TIME_MS].
const MAX_SPLASH_GATHER_TIME_MS = 2000;

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
/// | title             | 0     | 1..50, graded by longest common substring (50 when unrelated/below the overlap floor) | 1 |
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
/// - placeholder with desktop-entry name "Code - OSS" → 1 + 30 + 1 + 1 + 200
///   = 233 (class/title/startup/pid, the title sharing only its short app
///   suffix stays near the flat mismatch)
/// - placeholder renamed "Document — Code" via custom title → 203
/// → the custom-title placeholder wins, without any provenance involved.
MatchingCost windowMatchingCost(
  MatchingInfo metaWindowMatchInfo,
  MatchingInfo windowMatchInfo,
  Window window,
) {
  // The wmClass *must* match if specified
  final windowClass = matchingCost(
    windowMatchInfo.windowClass,
    metaWindowMatchInfo.windowClass,
    INF_COST,
    1,
  );
  final title = titleMatchingCost(
    windowMatchInfo.title,
    metaWindowMatchInfo.title,
  );
  final startupId = matchingCost(
    windowMatchInfo.startupId,
    metaWindowMatchInfo.startupId,
    1,
    1,
  );
  final pid = matchingCost(windowMatchInfo.pid, metaWindowMatchInfo.pid, 1, 1);
  final waiting = windowMatchInfo.waitingForAppSince != null
      ? 100 -
            (DateTime.now()
                        .difference(windowMatchInfo.waitingForAppSince!)
                        .inMilliseconds
                        .clamp(0, 1000) /
                    100)
                .round() // Clamp the difference to be between 0 and 1000 milliseconds
      : 200;

  return MatchingCost(
    windowClass: windowClass,
    title: title,
    startupId: startupId,
    pid: pid,
    waiting: waiting,
  );
}

/// Per-signal cost of matching a native window to a shell window.
///
/// [total] is the value the matcher ranks on; the individual fields keep a
/// matching decision explainable (read by the debug launch recorder).
class MatchingCost {
  const MatchingCost({
    required this.windowClass,
    required this.title,
    required this.startupId,
    required this.pid,
    required this.waiting,
  });

  final int windowClass;
  final int title;
  final int startupId;
  final int pid;
  final int waiting;

  int get total => windowClass + title + startupId + pid + waiting;

  Map<String, Object?> toJson() => {
        'windowClass': windowClass,
        'title': title,
        'startupId': startupId,
        'pid': pid,
        'waiting': waiting,
        'total': total,
      };

  @override
  String toString() => 'MatchingCost(total: $total)';
}
