
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
      <td>openssl</td>
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
      <td>GStreamer (runtime plugins vp8enc, webmmux, videoconvert, appsrc; gstreamer/gstreamer-app 0.24 cargo bindings; validated on 1.28)</td>
      <td>gst-plugins-good</td>
      <td>gst-plugins-good</td>
      <td>gst-plugins-good</td>
    </tr>
    <tr>
      <td>dbus-daemon session bus (tests + portal frontend)</td>
      <td>dbus</td>
      <td>dbus</td>
      <td>dbus</td>
    </tr>
   </tbody>
</table>
