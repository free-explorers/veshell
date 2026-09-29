import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/helm/control_panel/audio/widget/audio_control.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/widget/bluetooth_control.dart';
import 'package:shell/overview/helm/control_panel/media_player/widget/media_player_control.dart';
import 'package:shell/overview/helm/control_panel/network/widget/network_control.dart';

/// The control cards (media, audio, network, bluetooth).
///
/// The panel is intentionally not scrollable and does not own the session
/// controls, so it can be composed on its own or merged with the monitoring
/// panel inside a panel column.
class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MediaPlayerControl(),
        AudioControl(),
        NetworkControl(),
        BluetoothControl(),
      ],
    );
  }
}
