# Night Light

## Description

Night Light warms the colour temperature of every output at night, reducing
the blue light the screens give off. It turns on from the Helm's Display card,
or by itself on a daily schedule.

The compositor owns it (`src/embedder/night_light/`): it follows the schedule
whatever the shell does, and applies the tint where it costs nothing per frame.
The shell shows its state and sends the toggle.

## Behaviour

- **On** means the configured temperature; **off** means neutral (6500 K, the
  sRGB white point). Every change fades over two seconds in ten steps a
  second, interpolated in mireds so the tint changes evenly.
- **Schedule.** `display.nightLight.schedule` is `off` (only the toggle turns Night
  Light on) or `manual` (on every day from `display.nightLight.from` to
  `display.nightLight.to`, local time; a window whose end is before its start runs past
  midnight, and an empty window, `from == to`, never turns it on). The
  compositor re-evaluates the schedule at every local minute, which follows
  wall-clock and DST changes and catches up within a minute of a resume from
  sleep. No timer runs without a schedule.
- **Override.** The Helm toggle overrides the schedule until its next
  transition: turning Night Light off during the window keeps it off until the
  window ends; turning it on outside the window keeps it on until the window
  starts, after which the schedule keeps it on. Choosing what the schedule
  already says clears the override. Without a schedule, the toggle is the only
  switch. The override is in memory only: a restart follows the schedule again.
- **Startup** applies the current state at once, without a fade.

## Settings

They sit in the **Display** settings group, next to the monitors and
antialiasing. A `settings.json` written before the group existed (a top-level
`nightLight`, and `theme.antialiasing`) is moved to the new paths when the
compositor starts (`MOVED_SETTINGS` in `src/embedder/settings/mod.rs`); a
value already at the new path wins.

| Path | Values | Default |
|---|---|---|
| `display.nightLight.schedule` | `off`, `manual` | `off` |
| `display.nightLight.from` | `HH:MM`, 24-hour clock | `20:00` |
| `display.nightLight.to` | `HH:MM`, 24-hour clock | `06:00` |
| `display.nightLight.temperature` | kelvin, 1700–6500 | `2700` |

A malformed value falls back to its default; a temperature out of range is
clamped. The settings editor picks the times in half-hour steps (a hand-edited
time between them still works) and saves the temperature when the slider is
released, not at every step of the drag.

## Colour

The temperature is turned into the colour of a black body at that temperature:
its chromaticity on the Planckian locus (Kim et al. 2002 approximation),
converted to linear sRGB and taken relative to the 6500 K white. The gains are
normalised so the strongest channel stays at full scale (warming removes blue
and green, it never dims red), then gamma-encoded (2.2), because the lookup
table works on the encoded values the outputs scan out.

## Hardware

The gains are written to each CRTC's colour lookup table
(`Backend::set_color_gains`), so the tint covers every plane, the cursor and
directly scanned-out games, and stays out of screenshots, screencasts and
recordings, which capture the composite.

- An atomic device takes the CRTC's `GAMMA_LUT` blob, sized by
  `GAMMA_LUT_SIZE`; neutral clears the blob, so the hardware bypasses the
  lookup. A device without it takes the legacy gamma ramp, and so does an atomic
  driver that rejects `GAMMA_LUT` (`EINVAL`).
- A table is committed on its own, and only while no page flip is in flight
  on the CRTC; otherwise it waits for the CRTC's vblank. Smithay's commits
  never name the colour properties, so a table stays across its flips and
  modesets.
- A change while the session runs (a fade step) is committed like a page flip:
  non-blocking, with a flip event, so it shows at the next vblank and the
  backend handles that vblank as any flip's, holding rendering on the output
  until then. A blocking commit would stall the event loop for up to a frame
  per output instead. Each fade step therefore takes one vblank from
  rendering: at ten steps a second, the shell keeps five frames in six during
  a fade. A CRTC that is off (a blanked screen) takes the table at once,
  blocking; so does the legacy ramp, which always blocks.
- One-off writes (a new output, session activation, handing the device over)
  are blocking.
- A new output gets the current table at once, which also clears a table an
  earlier DRM master left behind. Before the session gives the device up (VT
  switch away, exit) every table is restored to neutral, so the next session,
  a greeter or the console is not tinted; activation writes the current table
  again. Logging out and stopping the session service send `SIGTERM`, which
  the compositor turns into its normal exit (`src/embedder/termination.rs`)
  so the restore runs then too.
- An output without a lookup table (some virtual and USB display drivers) is
  left untouched. When no output has one, Night Light is reported unsupported
  and the Helm hides the toggle.
- Only the DRM backend writes tables: a nested compositor must never tint its
  host.

## Platform channel

| Direction | Message | Payload |
|---|---|---|
| Compositor → shell | `night_light_changed` | `{ active, supported }` |
| Shell → compositor | `set_night_light` | `{ enabled }` |

`night_light_changed` is sent on every change of `active`, on output changes
(`supported` depends on the outputs) and when the shell starts.

## Helm

The Helm's Display card holds the brightness slider (when a backlight exists,
see [Monitor](monitor.md)) and the Night Light row (when it is supported); the
card is absent when neither is. With a schedule, the row's subtitle says when
Night Light changes next: "On until" the window's end while on, "Off until" the
window's start while off, in the locale's clock format.
