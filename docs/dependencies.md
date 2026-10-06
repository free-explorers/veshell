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

- Fontconfig, Roboto, and Noto fonts for all shipped scripts (see below).
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

### UI fonts

UI fonts are distribution-managed runtime dependencies, not bundled assets.
The shell requests `Roboto`, with `Noto Sans`, `Noto Sans Arabic` (also Urdu),
`Noto Sans Bengali`, `Noto Sans Devanagari` (Hindi), and `Noto Sans CJK`
families for Simplified Chinese (SC), Traditional Chinese (TC), Japanese (JP)
and Korean (KR) as fallbacks. Install all scripts, even for an English UI:
the language picker, app names and notifications can contain mixed languages.

| Distribution | Runtime font packages |
| --- | --- |
| Arch | `fontconfig`, `ttf-roboto`, `noto-fonts`, `noto-fonts-cjk` |
| Fedora | `fontconfig`, `google-roboto-fonts`, `google-noto-sans-fonts`, `google-noto-sans-arabic-fonts`, `google-noto-sans-bengali-fonts`, `google-noto-sans-devanagari-fonts`, `google-noto-sans-cjk-fonts` |
| Debian/Ubuntu | `fontconfig`, `fonts-roboto`, `fonts-noto-core`, `fonts-noto-cjk` |
| Nix/NixOS | `fontconfig`, `roboto`, `noto-fonts`, `noto-fonts-cjk-sans` (provided by the package/module) |

The Debian/RPM payload metadata declares the above font dependencies (RPM
names target Fedora; other RPM distributions must adapt them). The Nix wrapper
provides a Fontconfig configuration with those font packages while retaining
host font directories/configuration; an explicit `FONTCONFIG_FILE` override
remains respected. The NixOS module also installs the fonts system-wide.

Font versions, licenses, updates and caches are managed by the distribution;
rendering is not byte-for-byte identical across distributions. Missing families
may silently substitute other fonts or leave missing glyphs. After installation,
restart Veshell and check the actual environment with:

```sh
python3 extra/tests/system_fonts.py
```

The check requires only Python 3 and `fc-match`. It verifies family resolution
and coverage of the current ARB catalogs at regular, medium and bold weights.
If using a custom `FONTCONFIG_FILE`, run the check with that same environment.
