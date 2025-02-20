import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class BluetoothDeviceIcon extends StatelessWidget {
  const BluetoothDeviceIcon(this.icon, {super.key});
  final String icon;
  @override
  Widget build(BuildContext context) {
    return Icon(
      switch (icon) {
        'ac-adapter' => MdiIcons.power,
        'audio-card' => MdiIcons.expansionCard,
        'audio-headphones' => MdiIcons.headphones,
        'audio-headset' => MdiIcons.headset,
        'audio-input-microphone' => MdiIcons.microphone,
        'audio-speakers' => MdiIcons.speaker,
        'auth-fingerprint' => MdiIcons.fingerprint,
        'battery' => MdiIcons.battery,
        'camera-photo' => MdiIcons.camera,
        'camera-video' => MdiIcons.camera,
        'computer' => MdiIcons.laptop,
        'drive-harddisk' => MdiIcons.harddisk,
        'drive-harddisk-solidstate' => MdiIcons.harddisk,
        'drive-harddisk-usb' => MdiIcons.harddisk,
        'drive-multidisk' => MdiIcons.harddisk,
        'drive-optical' => MdiIcons.harddisk,
        'drive-removable-media' => MdiIcons.eject,
        'input-dialpad' => MdiIcons.dialpad,
        'input-gaming' => MdiIcons.gamepad,
        'input-keyboard' => MdiIcons.keyboard,
        'input-mouse' => MdiIcons.mouse,
        'input-touchpad' => MdiIcons.gestureTapButton,
        'input-tablet' => MdiIcons.tablet,
        'media-flash' => MdiIcons.usbFlashDrive,
        'media-floppy' => MdiIcons.floppy,
        'media-optical' => Icons.album,
        'media-removable' => MdiIcons.eject,
        'media-tape' => MdiIcons.tapeDrive,
        'multimedia-player' => MdiIcons.discPlayer,
        'network-wired' => MdiIcons.ethernetCable,
        'network-wireless' => MdiIcons.routerWireless,
        'pda' => MdiIcons.cellphone,
        'phone' => MdiIcons.phone,
        'printer' => MdiIcons.printer,
        'printer-network' => MdiIcons.printerWireless,
        'video-display' => MdiIcons.monitor,
        'preferences-desktop-keyboard' => MdiIcons.keyboard,
        'thunderbolt' => MdiIcons.bolt,
        String() => Icons.device_unknown,
      },
    );
  }
}
