# Lock screen

## Description

Locking the session blurs every monitor and asks for the user's password. The
session stays locked until PAM authenticates the user, by password or by
fingerprint, or until logind sends `Unlock`.

## Split

| Concern | Owner |
| --- | --- |
| Lock state, input blocking, game surface hiding | Compositor (`src/embedder/lock/`) |
| PAM transactions, logind signals, `LockedHint`, the sleep inhibitor | Compositor |
| Blur, clock, password field, PAM messages | Shell (`lib/lock_screen/`) |

The compositor owns the lock so that a shell that hangs, crashes or restarts
can never leave the session open. The shell only draws the lock screen and
relays what the user types.

## Triggers

- The `system.lockSession` hotkey (`Super+L` by default) and the power menu's
  lock button send the `lock_session` request.
- logind's `Lock` signal on this session (`loginctl lock-session`, other
  tools).
- logind's `PrepareForSleep(true)`: the compositor holds a `sleep` delay
  inhibitor, locks, and releases the inhibitor once the shell reports the lock
  screen drawn (`lock_screen_shown`), so the machine never resumes on an open
  desktop. logind proceeds anyway after `InhibitDelayMaxSec`. The inhibitor is
  taken again on resume.

The session is the one named by `XDG_SESSION_ID` (imported into the user
manager by `veshell-session`), or else the user's logind display session. The
compositor publishes `LockedHint` on it.

## While locked

- No key reaches a client, whatever Flutter does with it. Only brightness keys,
  VT switching and the compositor exit chord stay live in the compositor;
  `Print` is swallowed.
- Clients lose the keyboard focus (restored on unlock if still alive) and the
  pointer focus. No motion, button or scroll is forwarded. A focus requested
  while locked is recorded and applied on unlock instead.
- Gaming mode stops routing input to the game and its surface is not drawn
  over the Flutter frame. The game resumes after unlock.
- The shell blurs each monitor's content, excludes it from focus, and draws the
  lock screen outside the shortcut manager, so no shell hotkey fires.
- The lock screen is mounted beside the Navigator, so it brings its own
  `Material` and `Overlay`. Without them its text field cannot build properly,
  never takes the keyboard, and editing keys such as Backspace go unhandled.
- An eye button shows the password in clear. The password is hidden again on
  every lock.

## Authentication

Two PAM stacks run side by side on worker threads, as GDM does:

| Stack | Service file | Runs when |
| --- | --- | --- |
| Password | `/etc/pam.d/veshell` (`auth include login`) | Always |
| Fingerprint | `/etc/pam.d/veshell-fingerprint` (`pam_fprintd`) | The file exists and fprintd lists an enrolled finger |

The first stack to succeed unlocks. Only `pam_authenticate` runs; account and
session management are left alone, like other lock screens.

- The password stack starts on lock and waits on its prompt. The shell sends
  the answer with `lock_auth_respond`. After a failure the stack restarts, but
  only if it had prompted, so a broken PAM file cannot loop.
- Without an installed `veshell` service (an uninstalled development build),
  the password stack uses `login` so a developer is never locked out.
- The fingerprint stack restarts after a failure or timeout, up to three
  times in a row. A failed password attempt re-arms it.
- PAM text and error messages are shown as they come. An empty `failed`
  message means the credentials were rejected; the shell shows its own
  localized text.

## Platform channel

| Direction | Name | Payload |
| --- | --- | --- |
| Compositor → shell | `lock_state_changed` | `locked`, `userName`, `realName` |
| Compositor → shell | `lock_auth_update` | `source` (`password`/`fingerprint`), `kind` (`prompt`/`info`/`error`/`failed`/`unavailable`), `message`, `echo` |
| Shell → compositor | `lock_session` | none |
| Shell → compositor | `lock_auth_respond` | `response` (never logged) |
| Shell → compositor | `lock_screen_shown` | none |

On `shell_ready` the compositor replays the lock state, the pending prompt and
the last fingerprint message, so a restarted shell draws the lock screen again.

## Packaging

`make install` writes both PAM files to `PAMDIR` (`/etc/pam.d`; PAM ignores
install prefixes). The NixOS module declares them through
`security.pam.services`. Building needs the PAM development headers
([dependencies](../dependencies.md)).
