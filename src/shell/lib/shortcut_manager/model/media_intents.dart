import 'package:material_ui/material_ui.dart';

/// An intent to toggle play/pause on the active MPRIS player.
class MediaPlayPauseIntent extends Intent {
  ///
  const MediaPlayPauseIntent();
}

/// An intent to skip to the next track on the active MPRIS player.
class MediaNextIntent extends Intent {
  ///
  const MediaNextIntent();
}

/// An intent to skip to the previous track on the active MPRIS player.
class MediaPreviousIntent extends Intent {
  ///
  const MediaPreviousIntent();
}

/// An intent to stop the active MPRIS player.
class MediaStopIntent extends Intent {
  ///
  const MediaStopIntent();
}
