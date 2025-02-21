/// Weighted matching.
/// Matches N items on the "left" side with M items on the "right" side such that every item on the "left" side is part of exactly one match, and the total cost is minimized.
///
/// Takes an array `costs[N][M]` where costs[i][j] is the cost for assigning item i on the left hand side with item j on the right hand side.
///
/// Returns the minimum total cost for a valid assignment as well as the assignment indices.
/// In the return value, `assignments[i] = j` indicates that item `i` on the lhs was assigned to item `j` on the rhs.
///
/// Requires N <= M since otherwise not all items on the lhs can be matched.
///
/// This implements the Hungarian Algorithm.
/// Source: KACTL: https://github.com/kth-competitive-programming/kactl/blob/main/content/graph/WeightedMatching.h
///
/// See https://en.wikipedia.org/wiki/Assignment_problem
/// See https://en.wikipedia.org/wiki/Hungarian_algorithm
library;

import 'dart:typed_data';

class WeightedMatchingResult {
  WeightedMatchingResult(this.cost, this.assignments);
  final int cost;
  final Int32List assignments;
}

WeightedMatchingResult weightedMatching(List<List<int>> costs) {
  const intMax = 2147483647;

  if (costs.isEmpty) return WeightedMatchingResult(0, Int32List(0));
  final n = costs.length + 1;
  final m = costs[0].length + 1;
  if (n > m) {
    throw Exception(
      'Expected n <= m, otherwise not all items on the left hand side can be assigned',
    );
  }
  final u = Int32List(n);
  final v = Int32List(m);
  final p = Int32List(m);
  final ans = Int32List(n - 1);

  // Temporary arrays per loop
  final dist = Int32List(m);
  final pre = Int32List(m);
  final done = Int32List(m + 1); // Emulates a boolean array

  for (var i = 1; i < n; i++) {
    p[0] = i;
    var j0 = 0; // add "dummy" worker 0
    for (var j = 0; j < m; j++) {
      dist[j] = intMax;
      pre[j] = -1;
      done[j] = 0;
    }
    do {
      // dijkstra
      done[j0] = 1;
      final i0 = p[j0];
      var j1 = 0;
      var delta = intMax;
      for (var j = 1; j < m; j++) {
        if (done[j] == 0) {
          final cur = costs[i0 - 1][j - 1] - u[i0] - v[j];
          if (cur < dist[j]) {
            dist[j] = cur;
            pre[j] = j0;
          }
          if (dist[j] < delta) {
            delta = dist[j];
            j1 = j;
          }
        }
      }
      for (var j = 0; j < m; j++) {
        if (done[j] == 1) {
          u[p[j]] += delta;
          v[j] -= delta;
        } else {
          dist[j] -= delta;
        }
      }
      j0 = j1;
    } while (p[j0] != 0);
    while (j0 != 0) {
      // update alternating path
      final j1 = pre[j0];
      p[j0] = p[j1];
      j0 = j1;
    }
  }
  for (var j = 1; j < m; j++) {
    if (p[j] != 0) {
      ans[p[j] - 1] = j - 1;
    }
  }
  return WeightedMatchingResult(-v[0], ans); // min cost
}
