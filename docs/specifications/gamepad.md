# Gamepad

## Description

A gamepad (an Xbox or PlayStation pad, a Steam Deck's controls) drives the
shell's navigation: the D-pad and the left stick move the selection, a face
button activates, another dismisses. It reuses the [navigation](navigation.md)
intents, so a direction means what the focused context makes it mean, exactly
as for a keyboard chord.

Navigation only: the gamepad does not move a pointer and does not type text.
While a window is in [gaming mode](gaming_mode.md) the game has the pad to
itself; holding Guide leaves gaming mode.

## Split

| Concern | Owner |
| --- | --- |
| Finding the pads (udev, hotplug), reading them (evdev), the seat session | Compositor (`gamepad`) |
| Normalising buttons, the D-pad and the sticks to logical buttons | Compositor |
| Gaming mode: holding the pad back from the shell, the Guide hold | Compositor |
| Bindings (`gamepad.bindings`), chords, repeat, dispatching intents | Shell (`gamepad/`) |
| What an intent does | The focused context (see [Navigation](navigation.md)) |

## Devices

libinput does not handle joysticks, so the compositor reads them itself. Every
evdev node (`/dev/input/event*`) udev tags `ID_INPUT_JOYSTICK=1` is opened,
when present at startup and when plugged in later; a removed or unreadable
device is closed.

- The DRM backend opens them through the seat session, like libinput's
  devices. Switching VT revokes them: they are closed on pause and reopened on
  activation.
- The nested backend opens them directly; the session's `uaccess` ACL makes
  the user's joysticks readable.
- The isolated `veshell-probe` instance (`VESHELL_PROBE_ISOLATED=1`) never
  opens the developer's pads; it receives injected gamepad input instead.

The Steam Deck works either way: without Steam, hid-steam exposes its controls
as a gamepad (its trackpads are excluded, see below); with Steam running, Steam
hides that device and exposes a virtual Xbox pad, which is read the same way.

## Logical buttons

Every pad is reduced to one set of named buttons, by position (the Linux
gamepad API's naming): `south` is A on an Xbox pad, Cross on a PlayStation pad
and B on a Nintendo pad.

| Name | Source |
| --- | --- |
| `south`, `east`, `north`, `west` | `BTN_SOUTH`, `BTN_EAST`, `BTN_NORTH`, `BTN_WEST` |
| `leftShoulder`, `rightShoulder` | `BTN_TL`, `BTN_TR` |
| `leftTrigger`, `rightTrigger` | `BTN_TL2`, `BTN_TR2` (digital only) |
| `select`, `start`, `guide` | `BTN_SELECT`, `BTN_START`, `BTN_MODE` |
| `leftThumb`, `rightThumb` | `BTN_THUMBL`, `BTN_THUMBR` (stick presses) |
| `dpadUp`, `dpadDown`, `dpadLeft`, `dpadRight` | `BTN_DPAD_*`, or a hat switch `ABS_HAT0X/Y` with a `-1..1` range |
| `leftStickUp`… `leftStickRight` | `ABS_X`, `ABS_Y` |
| `rightStickUp`… `rightStickRight` | `ABS_RX`, `ABS_RY` |

- **Sticks** become digital directions. The deflection is normalised from the
  axis's own range (centred on its midpoint, so `0..255` pads work), a
  direction is pressed beyond 0.6 and released under 0.4. The hysteresis keeps
  a stick resting near the threshold from chattering, and stick noise never
  reaches the shell.
- A **hat** axis with a wider range is not a D-pad: the Steam Deck reports its
  left trackpad there, and a touch must not navigate.
- `BTN_TRIGGER_HAPPY*` is ignored: xpad reports a dance pad's D-pad there and
  hid-steam the Deck's back paddles, so the code has no portable meaning.
  Analog triggers (`ABS_Z`/`ABS_RZ`) are ignored for the same reason.
- **Several pads act as one**: a logical button is pressed while any pad holds
  it, and released when the last one lets go. A pad and the virtual pad Steam
  mirrors it to therefore never double a press.
- The kernel's autorepeat is ignored (the shell repeats itself), and a
  `SYN_DROPPED` releases everything the device held.

A press or release of a logical button counts as user activity for the idle
timers, in gaming mode too: a game played with a pad must not dim. Stick noise
below the thresholds does not count.

## Shell events

Each change is sent as `gamepad_button` with `{button, pressed}`. A release is
sent only for a press the shell received: a button pressed during gaming mode
gets no release after it, and entering gaming mode sends a release for every
button the shell still believes is held, so no direction keeps repeating behind
the game.

## Bindings

`gamepad.bindings` maps action ids to lists of **chords**: buttons held
together, joined by `+`. Every [keyboard action](navigation.md#bindings) is
bindable under the same group and name (`navigation.up`, `system.lockSession`,
`media.playPause`…). The gamepad adds the actions a keyboard reaches through
keys the framework or a local context binds:

| Action | Intent |
| --- | --- |
| `navigation.dismiss` | Flutter `DismissIntent` (what `Escape` does) |
| `navigation.cycleForward` / `cycleBackward` | `CycleIntent` (what `Super+Tab` does in the overview) |
| `overview.toggle` | `ToggleOverviewIntent` (what a lone `Super` does) |

Shipped defaults:

| Chord | Action |
| --- | --- |
| D-pad, left stick | Navigate |
| `leftShoulder` + D-pad / left stick | Move (reorder; send to the workspace above/below) |
| `south` | Activate |
| `east` | Dismiss |
| `select+north` | Close the focused tileable |
| `leftShoulder` / `rightShoulder` | Cycle backward / forward |
| `start`, `guide` | Toggle the overview |

`gamepad.repeatDelayMs` (400) and `gamepad.repeatIntervalMs` (120) pace the
repeat. An unknown action or a malformed chord is skipped and logged, never
turned into a binding.

## Resolution

A press resolves the exact set of buttons now held against the bindings,
whatever order they were pressed in. The intent is dispatched like a keyboard
shortcut: the nearest enabled action from the primary focus upwards
(`invokeGamepadIntent`).

- **Prefix chords fire on release.** A chord that is also the start of a longer
  one (a lone `leftShoulder`, since `leftShoulder+dpadLeft` is bound) fires
  when released with nothing else pressed meanwhile; otherwise every move would
  also cycle. This is the lone-Super rule of the overview toggle.
- **Directions repeat** (`NavigateIntent`, `MoveIntent`): once after the delay,
  then at the interval, until any button is pressed or released. Activation,
  dismissal, close and cycle never repeat.

## Gaming mode

While a window is in gaming mode nothing reaches the shell: the game reads the
pad itself, and a shell reacting to the same presses would navigate behind it.
The compositor keeps one gesture: **holding Guide for 800 ms leaves gaming
mode**, through the same exit as `Ctrl+Esc` (held keys are released to the
client, then the mode is cleared). The Guide press is never sent to the shell,
so it does not also toggle the overview on release.

## Non-goals

- Pointer emulation and text input (an on-screen keyboard).
- Analog triggers, rumble, LEDs, gyro, the Deck's trackpads and back paddles.
- Per-pad bindings: every pad shares one table.
- A settings editor: bindings are edited in `settings.json`.
- A windowed game outside gaming mode reads the pad while the shell navigates
  with it too; such a game belongs in gaming mode.
