# Dependencies

The table below lists build libraries and tools. The development SDK/bootstrap
also needs Git and working network access. Offline packaging supplies
the prepared shell and engine instead; see [building and packaging](building.md).

<table>
  <thead>
    <tr>
      <th>dependencies</th>
      <th>Arch</th>
      <th>Fedora</th>
      <th>Debian</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>rust</td>
      <td colspan=3><a href="https://rustup.rs/">https://rustup.rs/</a></td>
    </tr>
    <tr>
      <td colspan=4>make</td>
    </tr>
    <tr>
      <td colspan=4>cmake</td>
    </tr>
    <tr>
      <td colspan=4>clang</td>
    </tr>
    <tr>
      <td colspan=4>pkg-config</td>
    </tr>
    <tr>
      <td>ninja-build</td>
      <td>ninja</td>
      <td>ninja-build</td>
      <td>ninja-build</td>
    </tr>
    <tr>
      <td>gtk3</td>
      <td>gtk3</td>
      <td>gtk3-devel</td>
      <td>libgtk3-dev</td>
    </tr>
    <tr>
      <td>udev</td>
      <td>base-devel</td>
      <td>libudev-devel</td>
      <td>libudev-dev</td>
    </tr>
    <tr>
      <td>seat</td>
      <td>seatd</td>
      <td>libseat-devel</td>
      <td>libseat-dev</td>
    </tr>
    <tr>
      <td>libinput</td>
      <td>libinput</td>
      <td>libinput-devel</td>
      <td>libinput-dev</td>
    </tr>
    <tr>
      <td>gbm</td>
      <td>libgbm</td>
      <td>mesa-libgbm-devel</td>
      <td>libgbm-dev</td>
    </tr>
    <tr>
      <td>openssl</td>
      <td>openssl</td>
      <td>openssl-devel</td>
      <td>libssl-dev</td>
    </tr>
    <tr>
      <td>libstdc</td>
      <td></td>
      <td></td>
      <td>libstdc++-12-dev</td>
    </tr>
    <tr>
      <td>zbus 5 (cargo dependency, pure Rust)</td>
      <td colspan=3></td>
    </tr>
    <tr>
      <td>libpipewire-0.3 >= 1.0 (used from M2.3 / producer; pipewire 0.10 cargo bindings)</td>
      <td>pipewire</td>
      <td>pipewire-devel</td>
      <td>libpipewire-0.3-dev</td>
    </tr>
    <tr>
      <td>GStreamer build headers</td>
      <td>gstreamer, gst-plugins-base-libs</td>
      <td>gstreamer1-devel, gstreamer1-plugins-base-devel</td>
      <td>libgstreamer1.0-dev, libgstreamer-plugins-base1.0-dev</td>
    </tr>
    <tr>
      <td>dbus-daemon session bus (tests + portal frontend)</td>
      <td>dbus</td>
      <td>dbus</td>
      <td>dbus</td>
    </tr>
    <tr>
      <td>libnvidia-ml (optional: NVIDIA GPU monitoring, shipped with the NVIDIA driver; the GPU card is omitted when absent)</td>
      <td colspan=3></td>
    </tr>
   </tbody>
</table>

## Runtime requirements

- A usable DRM render node and compatible EGL/GLES drivers.
- A user session bus and a system D-Bus service.
- UPower and a PulseAudio-compatible audio server, such as PipeWire-Pulse.
  These are awaited during shell initialization, even on machines without a battery.
- Polkit and its authentication helper, with the helper location configured for
  the distribution. The socket transport is preferred; fallback helper paths
  must match the installed shell.
- GStreamer base/good plugins for capture: `appsrc`, `videoconvert`, `vp8enc`,
  and `webmmux`. Runtime packages include `gst-plugins-base`/`gst-plugins-good`
  on Arch, `gstreamer1-plugins-base`/`gstreamer1-plugins-good` on Fedora, and
  `gstreamer1.0-plugins-base`/`gstreamer1.0-plugins-good` on Debian.
- XWayland for X11 applications and an xdg-desktop-portal frontend/fallback
  backend for portal integration.

NetworkManager and BlueZ are optional integrations for their corresponding
shell controls. Enabling real-time audio through RTKit is recommended where
supported by the distribution.
