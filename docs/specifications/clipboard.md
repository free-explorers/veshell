# Clipboard

## Description

The clipboard is the seat's Wayland selection (`wl_data_device`), shared with
Xwayland through the X11 window manager. The compositor relays a selection
between the client that owns it and the one that reads it, and owns a
selection itself in two cases: a screenshot, and text copied in the shell.

## Split

| Concern | Owner |
| --- | --- |
| Wayland and X11 selections, relaying them between clients | Compositor (`clipboard`) |
| Payloads the compositor serves itself (screenshot, shell text) | Compositor (`NativeSelection`) |
| Copy, cut and paste in the shell's text fields | Flutter framework, through `flutter/platform` |

## Payloads the compositor owns

A compositor-owned selection carries a `NativeSelection` as its user data, and
is offered to Wayland and X11 clients alike (`set_native_clipboard`):

| Payload | Offered as |
| --- | --- |
| Screenshot | `image/png`, `application/x-veshell-screenshot` |
| Shell text | `text/plain;charset=utf-8`, `UTF8_STRING`, `text/plain`, `STRING`, `TEXT` |

A request is answered only in a type the payload is offered as; the bytes are
written off the event loop, so a slow reader never stalls the compositor. A
selection Xwayland owns is compositor-set with no payload and is relayed to
Xwayland.

## The shell's copy and paste

The framework's text fields reach the clipboard through its own platform
channel, `flutter/platform` (`SystemChannels.platform`, JSON codec), which the
embedder answers (`flutter_engine::system_platform`):

| Method | Answer |
| --- | --- |
| `Clipboard.setData` `{"text": ...}` | The text becomes the clipboard, owned by the compositor |
| `Clipboard.getData` `"text/plain"` | `{"text": ...}`, or null when the clipboard holds no text |
| `Clipboard.hasStrings` | `{"value": bool}`: whether the clipboard is offered as text (enables "Paste") |

Any other method of that channel is answered as not implemented.

`getData` answers text the shell copied at once. Text a client or Xwayland owns
is read through a pipe: the owner is asked for the first text type it offers,
in the order above, and the pipe is read on the event loop, which also serves
that owner, so the reply waits for the owner to close its end. A paste gives up
with no text after 2 seconds and reads at most 16 MiB.

The compositor records the MIME types of every new clipboard selection
(`State::clipboard_mime_types`) for `hasStrings`: Smithay only reports the
types of a selection a client sets, so the compositor records its own and
Xwayland's when it sets them.

## Invariants

- The shell, Wayland clients and X11 clients share one clipboard.
- The compositor never blocks its event loop on a clipboard transfer.
- A compositor-owned payload is never served in a type it is not offered as.
