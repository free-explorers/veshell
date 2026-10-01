import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/overview/helm/control_panel/media_player/widget/mpris_artwork.dart';
import 'package:shell/overview/helm/control_panel/media_player/widget/mpris_seek_bar.dart';
import 'package:shell/shared/mpris/model/mpris_loop_status.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';
import 'package:shell/shared/mpris/provider/mpris_manager.dart';

/// The media control card, or `null` when no player is on the session bus.
///
/// Returned as a section so the hosting `PanelColumn` can omit it entirely
/// when there is nothing to play. The header leads with the player's
/// application icon and identity (falling back to a music glyph and "Media");
/// with several players running it also offers a switcher, and until one is
/// picked the control follows whichever player is actually playing.
Widget? mediaPlayerSection(WidgetRef ref) {
  final state = ref.watch(mprisManagerProvider).value;
  final player = state?.activePlayer;
  if (player == null || state == null) {
    return null;
  }

  return Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MediaHeader(
            player: player,
            players: state.playerList,
            canRaise: player.canRaise,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _NowPlaying(player: player),
          ),
          if (player.canSeek && player.track.length != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: MprisSeekBar(player: player),
            ),
          ],
          const SizedBox(height: 8),
          _TransportControls(player: player),
        ],
      ),
    ),
  );
}

class _MediaHeader extends ConsumerWidget {
  const _MediaHeader({
    required this.player,
    required this.players,
    required this.canRaise,
  });

  /// The active player, whose icon and identity head the card.
  final MprisPlayer player;

  /// Every known player, for the switcher.
  final List<MprisPlayer> players;

  final bool canRaise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final identity = player.identity;
    return Row(
      children: [
        SizedBox.square(
          dimension: 24,
          child: AppIconById(
            id: player.iconId,
            fallback: Icon(
              MdiIcons.musicNote,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            identity.isEmpty ? 'Media' : identity,
            style: theme.textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (canRaise)
          IconButton(
            tooltip: 'Bring to front',
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(mprisManagerProvider.notifier).raise(),
            icon: const Icon(MdiIcons.openInNew),
          ),
        if (players.length > 1)
          PopupMenuButton<String>(
            tooltip: 'Switch player',
            icon: const Icon(MdiIcons.playlistMusic),
            initialValue: player.busName,
            onSelected: (busName) =>
                ref.read(mprisManagerProvider.notifier).selectPlayer(busName),
            itemBuilder: (context) => [
              for (final candidate in players)
                PopupMenuItem(
                  value: candidate.busName,
                  child: Row(
                    children: [
                      Icon(
                        candidate.busName == player.busName
                            ? MdiIcons.check
                            : MdiIcons.musicNote,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          candidate.identity.isEmpty
                              ? candidate.busName
                              : candidate.identity,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.player});

  final MprisPlayer player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = player.track;
    final subtitle = track.displaySubtitle.isNotEmpty
        ? track.displaySubtitle
        : player.identity;
    return Row(
      children: [
        MprisArtwork(url: track.artUrl),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                track.displayTitle ?? 'Nothing playing',
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.player});

  final MprisPlayer player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mprisManagerProvider.notifier);
    final canToggle =
        player.canControl &&
        (player.isPlaying ? player.canPause : player.canPlay);
    final enabled = player.canControl;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (enabled)
          IconButton(
            tooltip: 'Shuffle',
            isSelected: player.shuffle,
            onPressed: notifier.toggleShuffle,
            icon: const Icon(MdiIcons.shuffle),
          ),
        IconButton(
          tooltip: 'Previous',
          onPressed: enabled && player.canGoPrevious ? notifier.previous : null,
          icon: const Icon(MdiIcons.skipPrevious),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: IconButton.filled(
            tooltip: player.isPlaying ? 'Pause' : 'Play',
            iconSize: 32,
            onPressed: canToggle ? notifier.playPause : null,
            icon: Icon(player.isPlaying ? MdiIcons.pause : MdiIcons.play),
          ),
        ),
        IconButton(
          tooltip: 'Next',
          onPressed: enabled && player.canGoNext ? notifier.next : null,
          icon: const Icon(MdiIcons.skipNext),
        ),
        if (enabled)
          IconButton(
            tooltip: 'Repeat',
            isSelected: player.loopStatus != MprisLoopStatus.none,
            onPressed: notifier.cycleLoopStatus,
            icon: Icon(switch (player.loopStatus) {
              MprisLoopStatus.none => MdiIcons.repeatOff,
              MprisLoopStatus.playlist => MdiIcons.repeat,
              MprisLoopStatus.track => MdiIcons.repeatOnce,
            }),
          ),
      ],
    );
  }
}
