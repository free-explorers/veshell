/// Index of the selection after moving by [delta] over a list of [length]
/// entries, given the current [currentIndex] (`-1` when nothing is selected).
///
/// The selection clamps at the ends. Returns `-1` for an empty list.
int nextSelectionIndex({
  required int currentIndex,
  required int delta,
  required int length,
}) {
  if (length <= 0) {
    return -1;
  }
  if (currentIndex < 0) {
    return 0;
  }
  return (currentIndex + delta).clamp(0, length - 1);
}
