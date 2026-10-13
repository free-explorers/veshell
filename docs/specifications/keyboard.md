# Keyboard input

## Description

Every hardware key event is intercepted before it can reach a client
(`handle_keyboard_event`, `src/embedder/keyboard/`). Smithay updates the seat's
xkb state, the compositor resolves its own hotkeys and routes the rest to
Flutter, and Flutter answers whether the shell consumed the sequence. Only
events the shell did not consume are forwarded to the focused client.

This ordering lets the shell own global shortcuts (volume, media, layout
navigation) without the client ever seeing the keys, while ordinary typing still
flows through to the client.

## Split

| Concern | Owner |
| --- | --- |
| Seat xkb state, hardware events, hotkeys the compositor owns (brightness, VT switch, `Meta+Alt+Del`, `Ctrl+Esc`) | Compositor |
| Global shell hotkeys and their resolution | Shell (Flutter) |
| Forwarding unconsumed key events to the focused client | Compositor |
| Key repetition | Client, by Wayland contract; the shell gets a compositor-side copy |

## Key repetition

Wayland leaves key repetition to the **client**. The compositor advertises the
user's preference through `wl_keyboard.repeat_info(rate, delay)` — `rate` in
characters per second (`0` disables repeating) and `delay` in milliseconds — and
clients (GTK, Qt, GLFW, SDL, XWayland, …) repeat held keys themselves. Mutter
and Weston follow the same rule: they never forward their own autorepeat to
Wayland clients.

Flutter is the exception: the shell is a key consumer — text fields, hotkey
handling, the overview — that does not repeat on its own. The compositor
therefore runs its own repeater (`KeyRepeater`) to feed the shell
`KeyRepeatEvent`s.

These repeats are **delivered to Flutter only**. They are never forwarded to the
focused client: doing so would double every held key, because the client is
already repeating the same key from `repeat_info`. The repeats also never mutate
the Super-shortcut forwarding state, since they are not key transitions.

The advertised values and the repeater share one source of truth:
`State::repeat_delay` (ms) and `State::repeat_rate` (characters/second). The
repeater derives its timer interval as `1000 / rate`, so the shell repeats at
the same pace clients are told to. The defaults — 500 ms delay and 30
characters/second — are within the range mainstream desktops ship (GNOME and
Windows use a 500 ms delay; KDE and X11 repeat at 25/s).

The preference is user-facing under `keyboard` in `settings.json`:

| Setting | Meaning | Default |
| --- | --- | --- |
| `repeat` | Whether holding a key repeats it at all | `true` |
| `repeatDelayMs` | Milliseconds before repetition starts | `500` |
| `repeatRate` | Repeats per second while held (`0` disables) | `30` |

Disabling `repeat` is advertised as a rate of `0`, which turns off both client
repetition (through `repeat_info`) and the shell repeater. A settings change
re-applies both through `apply_veshell_settings`.

## Layouts

The seat's keymap can carry several layouts at once. `keyboard.layout` is a
comma-separated xkb list (`us(altgr-intl),ru`); each entry may name a variant in
parentheses. The compositor compiles the whole list into a single keymap through
`XkbConfig::layout`, both at seat creation and whenever
`apply_veshell_settings` re-runs.

Switching is a shell-owned global hotkey, like the others. The shipped default
binds `system.toggleKeyboardLayout` to `Super+Space`; pressing it runs the
`ToggleKeyboardLayout` intent, which sends the `switch_keyboard_layout` platform
request. The compositor answers with `KeyboardHandle::with_xkb_state` →
`XkbContext::cycle_next_layout`, advancing the active xkb group and broadcasting
the modifier/group change to the focused client. The cycle follows the
configured order and wraps from the last layout back to the first.

The settings UI edits the list as one entry per layout and persists it
comma-separated, so a single-layout configuration still deserializes and leaves
the toggle inert (cycling always lands on the first layout).

## Invariants

- Every physical key event is offered to Flutter before any client sees it.
- A client never receives a compositor-synthesized repeat; clients own their own
  repetition from `repeat_info`.
- The shell's repeats reach Flutter even while a client is focused, so shell
  text fields and hotkeys behave the same regardless of focus.
- A repeat is only emitted while its key is still physically held: a release that
  races the timer cancels the repeat rather than emitting a stray character.
- The delay and rate advertised to clients match the shell repeater's behavior.
- Leaving gaming mode releases every key the client believes is held and stops
  any in-flight shell repeat (`release_flutter_keys`).
