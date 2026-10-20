#!/usr/bin/env bash
set -euo pipefail

repo=$(realpath "$(dirname "$0")/../..")
tmp=$(mktemp -d "${TMPDIR:-/tmp}/veshell-session-teardown.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

log="$tmp/calls.log"
mkdir -p "$tmp/tools"

# `is-active` always fails so the wrapper takes the normal (not the stale
# recovery) path and starts nothing for real. Every other call succeeds and is
# recorded so the assertions below can inspect the teardown.
cat > "$tmp/tools/systemctl" <<'EOF'
#!/bin/sh
printf 'systemctl %s\n' "$*" >> "$LOG"
case " $* " in
    *" -q is-active "*) exit 1 ;;
esac
exit 0
EOF
cat > "$tmp/tools/dbus-update-activation-environment" <<'EOF'
#!/bin/sh
printf 'dbus-update-activation-environment %s\n' "$*" >> "$LOG"
exit 0
EOF
chmod +x "$tmp/tools/systemctl" "$tmp/tools/dbus-update-activation-environment"

run() {
    : > "$log"
    # Without a login shell the wrapper runs the script in place instead of
    # re-executing itself through $SHELL.
    env -u SHELL LOG="$log" PATH="$tmp/tools:$PATH" bash "$@"
}

expect() {
    grep -Fx "$1" "$log" > /dev/null || {
        printf 'Missing call: %s\n' "$1" >&2
        cat "$log" >&2
        exit 1
    }
}

check_teardown() {
    expect 'systemctl --user unset-environment WAYLAND_DISPLAY DISPLAY WAYLAND_SOCKET XDG_SESSION_TYPE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION'
    expect 'dbus-update-activation-environment XDG_CURRENT_DESKTOP= XDG_SESSION_DESKTOP= DESKTOP_SESSION='
}

# The wrapper's own teardown path (normal exit and signal trap share it).
run "$repo/extra/assets/veshell-session"
check_teardown

# ExecStop must perform the same cleanup when the compositor goes away without
# the wrapper getting a chance to run its teardown.
run "$repo/extra/assets/veshell-session-stop"
check_teardown

printf 'Session teardown tests passed.\n'
