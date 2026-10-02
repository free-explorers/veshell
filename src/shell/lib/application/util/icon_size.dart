/// Icon decode buckets, in physical pixels.
///
/// App icons are requested from layouts at arbitrary sizes (an `AspectRatio`,
/// a panel cell, a window header…). Decoding at every distinct request size is
/// what made the old icon cache grow without bound, so requests are snapped up
/// to one of these buckets instead. The steps stay small enough that a scaled
/// bucket is visually indistinguishable from the exact size.
const iconPixelBuckets = <int>[16, 24, 32, 48, 64, 96, 128, 256];

/// The physical-pixel size an icon should be decoded at for [logicalSize].
///
/// [devicePixelRatio] comes from the view. The shell used to decode at the
/// logical size and let the compositor upscale, which is blurry on HiDPI;
/// multiplying by the device pixel ratio keeps icons crisp and makes a
/// [logicalSize] map to a stable bucket rather than to every integer the
/// layout can produce.
int iconPhysicalBucket(double logicalSize, double devicePixelRatio) {
  final physical = (logicalSize * devicePixelRatio).ceil();
  for (final bucket in iconPixelBuckets) {
    if (physical <= bucket) {
      return bucket;
    }
  }
  return iconPixelBuckets.last;
}
