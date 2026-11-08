# TileableWindow

## Description

a TileableWindow is a [Tileable](tileable.md) that represent an application window that persist in the layout even when it's closed.

## Launch lifecycle

A launch runs the application through `AppLaunch` in a tracked
`veshell-launch-<tile-uuid>-*.service` unit. Removing the tile while the launch
has not produced a native window cancels that unit (`systemctl --user stop`,
i.e. SIGTERM to the cgroup); once a window is displayed the tile is no longer
pending and the application exits by closing its window. A launch whose process
is already showing a window under another tile is left running.

While the session is leaving (logout, reboot, shutdown), window-loss and
title-change events are transient: the tile does not persist them, so the last
complete window state survives into the next session. See
[state_manager.md](state_manager.md).

## Opening and closing

A tile's own launch opens its first window through the placeholder's centered
card: the window, already at its final place and size, shows through the card,
then the opening expands to the tile's edges as its corners straighten.

Closing plays it backwards: the placeholder is shown whole at once, and the
window wraps back into its card over it (the opening narrows to the card, its
corners round, then the window fades out into the card's content). A closed
window has no surface left to paint, so when the shell asks it to close (the
tab's close button, the close shortcut, the menu, a middle click) the tile's
frame is captured at that moment and is what wraps up: what the shell painted,
and the window's own frame, which the compositor copies into a texture of its
own as the request arrives, before the client handles it. Nothing the client
paints afterwards (its teardown, a recycled buffer) reaches the copy, and a
window that stays (a client asking first about unsaved changes) keeps painting
normally. The shell releases the copy once the closing is over, the compositor
after 5 seconds at most; a captured frame is dropped after 5 seconds if the
window stays. A window that closes on its own (the application quitting,
crashing or being killed) wraps up the same way from the last frame it
committed, which a client that is gone can no longer change: the compositor
keeps that texture for the closing, and the shell remembers where it was
painted, so it shows over a plain surface in place of the frame the shell did
not capture. A window shown again (a splash handing over, a recreated surface)
cancels the closing. Floating tiles, and the shell with animations disabled,
do neither.

The tile's last frame is also persisted, as `window_previews/<uuid>.png` in the
compositor's cache directory (`VESHELL_CACHE_DIR`, by default
`$XDG_CACHE_HOME/veshell`): from the frame captured when the shell asks the
window to close, or else from the window's last committed frame when it is
removed. Nothing is copied while the window lives. The compositor stores the
window's content (without client-side decorations) averaged down to one pixel
per frost sigma (`frostSigmaFor`) and blurred by one more pixel, so the file
never holds a readable window: what was averaged together cannot be recovered,
and scaled back up it matches the shell's frost. A frame with nothing to show
(fully transparent, or one plain colour, as a client clearing its window as it
quits) is not stored, and the previous preview stays. The file is readable by
the user only. A sidecar, `<uuid>.layout`, written by the shell once the window
is gone, records the window's content size and whether it filled its tile. The
placeholder paints the stored frame at that size under the same glass as the
dialog backdrop and the overview (vibrancy, wash and grain), instead of the
application icon, until the tile displays a window again; the closing
animation ramps the live frame to that same frost. The files are removed with
the tile, once the compositor stopped writing for it, and the compositor
removes at startup the previews of tiles whose state is gone.

## Resume context

A tile that has no window resumes its saved work when clicked; it is never
started "fresh". Fresh launches remain the launcher's job (overview/app
drawer), and nothing is started automatically at shell startup.

The context lives in `PersistentWindow.resumeContext`, separate from
`properties` (which follows the currently displayed window and is overwritten
by helper surfaces). It stores:

- the saved working directory;
- the captured argv (fallback command line);
- the executable identity;
- the tracked-launch cgroup, used to find sibling tiles;
- terminal shell/working directory and the foreground program to replay;
- the capture time.

### Capture

The context is captured from the launch configuration, refreshed from
`process_info` when a window maps and when its title changes, and polled every
2 seconds while the tile displays a window. Rust reads `/proc/<pid>/cmdline`,
`cwd`, `exe`, and — for terminal windows — the shell descendant and its
foreground job. Capture never blocks a launch; unreadable `/proc` facts simply
leave the previous context in place.

Windows started outside the shell are captured the same way: the displayed
process is the source of truth, not the fact that this shell launched it.

### Relaunch

1. A custom exec remains a shell command; the saved cwd applies.
2. Otherwise the desktop entry's `Exec` is parsed into argv, `%f/%F/%u/%U` are
   filled from saved documents, `%i/%c` are expanded, and non-document
   arguments are appended. Arguments and paths are never interpolated into a
   shell string; `systemd-run` receives them as discrete argv elements.
3. If the desktop entry is gone, the captured argv/executable is used.
4. A saved cwd that is gone falls back to `$HOME` (then the compositor cwd);
   a tile with no captured context keeps the compositor cwd. A missing
   document is dropped, and an unusable command leaves the tile as a
   placeholder. The click is never refused because part of the context is
   stale.

### Sibling tiles

The clicked tile owns the launch gather. After the burst settles, the matching
engine distributes the extra windows to matching sibling tiles by title; the
application is launched only once. There is deliberately no separate sibling
arming: letting a sibling compete before the settle would skip the title
arbitration for windows that restore their title later.

### Failure, retry and forgetting

A resume that produces no window within ~25 seconds clears the waiting state,
keeps the context and shows Retry / Forget. Retry cancels a still-pending
launch before starting again, so it cannot spawn a duplicate. Forget clears the
tile's resume context and title but keeps the tile, its app id, display mode and
custom exec.

Closing a window does not clear the context. Only Forget or removing the tile
does.

The placeholder says **Start** with the application name while a tile has no
saved context yet, and **Resume** with the saved summary afterwards.

When no desktop entry matches the tile's app id, the placeholder shows the
tile's last saved title and the saved command (captured argv, then executable)
instead of "Unknown". The saved command is the same fallback relaunch uses, so
the tile does not hide the command it will actually run.

The resume summary only names facts that describe resumable work: a terminal's
directory and foreground program, an opened document, or the last window title.
A non-terminal application's working directory is not shown: most applications
ignore it on launch, and applications such as IDEs restore their own workspace
or project instead.

## Terminal resume

For a terminal window the tile stores the shell and the shell's cwd, plus a
foreground program when it is safe to replay.

### What is captured

A foreground program is stored only when all of these hold:

- Rust reported it as the shell's actual foreground job (`tpgid`, not merely a
  child process);
- its basename is on the allowlist in
  `src/shell/lib/application/model/terminal_program_policy.dart`
  (editors, pagers, monitors, file managers, multiplexers and `man`/`info`);
- it is not a shell, not in the explicit denylist, and not a build tool,
  interpreter, package manager or remote-session command;
- its captured executable still exists and is executable.

Shells, `ssh`, `sudo`, package managers, builds, scripts and arbitrary commands
are never replayed. If the program cannot be represented safely, the tile keeps
the shell cwd only.

### Resume

The terminal starts in the shell cwd, then the saved program is run inside it:

```text
/bin/sh -c 'if [ -n "$1" ]; then printf "\033]0;%s\007" "$1"; fi; shift; "$@"; exec "$0"' <shell> <title> <program> <args...>
```

The wrapper is non-interactive and non-login. When the program exits, it execs
the captured shell, so the terminal stays at an interactive prompt. Program and
arguments are positional argv elements, never shell-interpolated text.

Before starting the program, the wrapper seeds the terminal title with the
tile's saved window title (control characters stripped, length bounded); when
that title is empty or only the terminal emulator's own name, the program's
basename is used instead. The title normally comes from the interactive shell's
prompt hook, which does not run while the program is alive; without seeding, a
resumed `htop` would keep the terminal emulator's own title (`Alacritty`) instead
of `htop`.

The wrapper is an implementation detail of the resume, not part of the captured
context: process inspection unwraps it and reports the shell it will exec and
the program it is running. That is what lets a second close and resume replay
the same program instead of falling back to a fresh shell.

Command separators come from a small terminal table:

- `alacritty`, `xterm`, `urxvt`, `st`, `sakura`, `konsole`,
  `xfce4-terminal`, `ghostty` → `-e` / `-x` variants;
- `foot`, `kitty`, `gnome-terminal`, `kgx` → `--`;
- `wezterm` → `start --`, with `--cwd` when a cwd flag is needed.

Known terminals also get their own working-directory flag where the emulator
uses a server and would otherwise ignore the inherited cwd. An unknown terminal
is not guessed: the tile opens its normal shell in the saved cwd and drops the
program with a log line. A missing program, a non-executable program or a
missing shell does the same.

`htop` is therefore resumed; `ssh`, `sudo`, `make` and arbitrary scripts are
not.

### Custom exec

A tile with a custom exec keeps it as the base command and still applies the
saved cwd. If the custom command is a recognised terminal without a command
separator, the saved foreground is appended with that terminal's syntax. If it
already supplies a command (`-e`, `--`, `--command`, ...), it is left alone. A
non-terminal custom command never gets a terminal program appended.

### Refresh

Shell cwd and foreground are refreshed while the terminal window lives (title
changes and the 2-second process-info poll). The last context is kept when the
window closes; closing the terminal does not forget it.

## Properties

WindowState state; // placeholder or opened  
List<[Window]()> modalList;  
