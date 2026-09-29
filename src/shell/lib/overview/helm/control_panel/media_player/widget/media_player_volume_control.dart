import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/shared/mpris/model/mpris_player.dart';
import 'package:shell/shared/mpris/provider/mpris_manager.dart';

/// The MPRIS players' own volumes, as rows in the Volume card.
///
/// This is deliberately separate from the system output volume next to it:
/// the PulseAudio slider drives the sink, while the MPRIS `Volume` property is
/// each player's internal volume, applied before it reaches that sink. Every
/// known player gets its own row, so several players can be adjusted without
/// switching the active one. The widget renders nothing when no player is
/// present.
class MediaPlayerVolumeControl extends ConsumerWidget {
  const MediaPlayerVolumeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(mprisManagerProvider).value?.playerList;
    if (players == null || players.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final player in players) _PlayerVolumeRow(player: player),
      ],
    );
  }
}

/// One player's volume: its application icon, a mute toggle and a slider.
class _PlayerVolumeRow extends ConsumerWidget {
  const _PlayerVolumeRow({required this.player});

  final MprisPlayer player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mprisManagerProvider.notifier);
    final muted = player.volume <= 0;
    final enabled = player.canControl;
    return ListTile(
      title: Row(
        children: [
          _PlayerIcon(iconId: player.iconId),
          const SizedBox(width: 16),

          IconButton(
            tooltip: muted ? 'Unmute player' : 'Mute player',
            onPressed: enabled
                ? () => notifier.setVolumeFor(player.busName, muted ? 1.0 : 0.0)
                : null,
            icon: Icon(muted ? MdiIcons.volumeOff : MdiIcons.volumeHigh),
          ),
          Expanded(
            child: Slider(
              value: player.volume.clamp(0.0, 1.0),
              onChanged: enabled
                  ? (value) => notifier.setVolumeFor(player.busName, value)
                  : null,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// The player's application icon, resolved from its desktop entry.
///
/// [iconId] is the MPRIS `DesktopEntry` when the player advertises one, or the
/// name from its bus name otherwise. Players the desktop-entry lookup cannot
/// resolve keep a neutral music glyph, so the row always identifies what it
/// controls.
class _PlayerIcon extends StatelessWidget {
  const _PlayerIcon({required this.iconId});

  final String iconId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox.square(
        dimension: 26,
        child: AppIconById(
          id: iconId,
          fallback: Icon(
            MdiIcons.musicNote,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
