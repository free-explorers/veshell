import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/mpris/model/mpris_playback_status.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';
import 'package:shell/shared/mpris/provider/mpris_manager.dart';

/// The track progress bar of the media control.
///
/// The player reports `Position` only once a second (MPRIS does not stream it),
/// so the bar interpolates from the last sample every 500 ms while playing and
/// snaps to the dragged value while the user seeks.
class MprisSeekBar extends HookConsumerWidget {
  const MprisSeekBar({required this.player, super.key});

  final MprisPlayer player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final length = player.track.length;
    if (length == null || length <= Duration.zero) {
      return const SizedBox.shrink();
    }

    // The value currently being dragged, or null when following playback.
    final dragging = useState<Duration?>(null);
    // A tick that forces a rebuild as playback advances between position polls.
    final tick = useState(0);

    useEffect(() {
      if (player.playbackStatus != MprisPlaybackStatus.playing) {
        return null;
      }
      final timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        tick.value++;
      });
      return timer.cancel;
    }, [player.playbackStatus, player.track.trackId]);

    final maxMicros = length.inMicroseconds.toDouble();
    final estimated = player.estimatedPositionAt(DateTime.now());
    final currentMicros = (dragging.value ?? estimated).inMicroseconds
        .toDouble()
        .clamp(0.0, maxMicros);
    final current = Duration(microseconds: currentMicros.round());

    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Row(
      children: [
        Text(_formatDuration(current), style: labelStyle),
        Expanded(
          child: Slider(
            value: currentMicros,
            max: maxMicros,
            onChanged: player.canSeek
                ? (value) {
                    dragging.value = Duration(microseconds: value.round());
                  }
                : null,
            onChangeEnd: player.canSeek
                ? (value) {
                    dragging.value = null;
                    ref
                        .read(mprisManagerProvider.notifier)
                        .seekTo(Duration(microseconds: value.round()));
                  }
                : null,
          ),
        ),
        Text(_formatDuration(length), style: labelStyle),
      ],
    );
  }

  /// Formats a duration as `m:ss`, or `h:mm:ss` past the hour.
  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final seconds = totalSeconds % 60;
    final minutes = totalSeconds ~/ 60;
    if (minutes < 60) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours:${remainingMinutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
