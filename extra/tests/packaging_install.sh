#!/usr/bin/env bash
set -euo pipefail

repo=$(realpath "$(dirname "$0")/../..")
tmp=$(mktemp -d "${TMPDIR:-/tmp}/veshell-packaging.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/fixture with spaces"
mkdir -p "$fixture/lib/nested" "$fixture/data/flutter_assets/nested" "$fixture/settings/default" "$tmp/tools"
printf 'binary\n' > "$fixture/veshell"
printf 'external engine\n' > "$fixture/engine.so"
printf 'wrong bundle engine\n' > "$fixture/lib/libflutter_engine.so"
printf 'unused GTK engine\n' > "$fixture/lib/libflutter_linux_gtk.so"
printf 'AOT\n' > "$fixture/lib/libapp.so"
printf 'plugin\n' > "$fixture/lib/libplugin.so.1"
ln -s libplugin.so.1 "$fixture/lib/libplugin.so"
printf 'nested plugin\n' > "$fixture/lib/nested/libnested.so"
printf 'asset\n' > "$fixture/data/flutter_assets/nested/asset"
printf 'hidden asset\n' > "$fixture/data/.hidden"
printf '{}\n' > "$fixture/settings/default/settings.json"
printf '#!/bin/sh\nexit 99\n' > "$tmp/tools/cargo"
printf '#!/bin/sh\nexit 99\n' > "$tmp/tools/sudo"
chmod +x "$tmp/tools/cargo" "$tmp/tools/sudo"
original_path=$PATH
export PATH="$tmp/tools:$PATH"

args=(-C "$repo" --no-print-directory
    "BIN=$fixture/veshell" "ENGINE_LIB=$fixture/engine.so"
    "APP_LIB=$fixture/lib/libapp.so" "DATA_DIR=$fixture/data"
    "SETTINGS_DIR=$fixture/settings" "SERVICE_OUTPUT=$tmp/veshell.service")
run() { make "${args[@]}" "$@" > "$tmp/make.log" 2>&1 || { cat "$tmp/make.log"; return 1; }; }
reject() { if make "${args[@]}" "$@" > "$tmp/make.log" 2>&1; then printf 'Unexpected success: %s\n' "$*" >&2; exit 1; fi; }

for prefix in /usr '/opt/veshell prefix&pipe|' '/opt/percent%quote"back\ dollar$`tick'; do
    # Command-line Make variables need literal dollar signs doubled.
    make_prefix=${prefix//\$/\$\$}
    run install "PREFIX=$make_prefix" "DESTDIR=$tmp/root"
    root="$tmp/root$prefix"
    test -x "$root/bin/veshell"
    test -x "$root/bin/veshell-session"
    test -x "$root/bin/veshell-session-stop"
    cmp "$fixture/engine.so" "$root/lib/veshell/libflutter_engine.so"
    cmp "$fixture/lib/libapp.so" "$root/lib/veshell/libapp.so"
    test -L "$root/lib/veshell/libplugin.so"
    cmp "$fixture/lib/libplugin.so.1" "$root/lib/veshell/libplugin.so"
    test -f "$root/lib/veshell/nested/libnested.so"
    test ! -e "$root/lib/veshell/libflutter_linux_gtk.so"
    test -f "$root/share/veshell/data/flutter_assets/nested/asset"
    test -f "$root/share/veshell/data/.hidden"
    test -f "$root/share/veshell/settings/default/settings.json"
    test -f "$root/share/wayland-sessions/veshell.desktop"
    test -f "$root/share/xdg-desktop-portal/veshell-portals.conf"
    test -f "$root/share/xdg-desktop-portal/portals/veshell.portal"
    test -f "$root/lib/systemd/user/veshell-shutdown.target"
    service_prefix="$prefix"
    desktop_prefix="$prefix"
    if [[ "$prefix" == '/opt/percent%quote"back\ dollar$`tick' ]]; then
        service_prefix='/opt/percent%%quote\"back\\ dollar$$`tick'
        desktop_prefix='/opt/percent%%quote\\"back\\\\ dollar\\$\\`tick'
    fi
    grep -Fx "ExecStart=\"$service_prefix/bin/veshell\" --session" "$root/lib/systemd/user/veshell.service"
    grep -Fx "ExecStop=\"$service_prefix/bin/veshell-session-stop\"" "$root/lib/systemd/user/veshell.service"
    grep -Fx "Exec=\"$desktop_prefix/bin/veshell-session\"" "$root/share/wayland-sessions/veshell.desktop"
    if grep -F "$tmp/root" "$root/lib/systemd/user/veshell.service"; then exit 1; fi
    if grep -F "$tmp/root" "$root/share/wayland-sessions/veshell.desktop"; then exit 1; fi
done

# The Nix alias and every final path override use the same installer.
run package "DESTDIR=$tmp/custom" BINDIR=/custom/bin LIBDIR=/custom/lib SHAREDIR=/custom/share \
    SESSIONDIR=/custom/sessions PORTALDIR=/custom/portals SYSTEMD_USER_DIR=/custom/units
test -f "$tmp/custom/custom/units/veshell.service"
test -f "$tmp/custom/custom/portals/portals/veshell.portal"
test -f "$tmp/custom/custom/lib/libplugin.so.1"
grep -Fx 'Exec="/custom/bin/veshell-session"' "$tmp/custom/custom/sessions/veshell.desktop"

# No bundle engine may overwrite a separately supplied runtime symlink.
ln -s "$fixture/engine.so" "$tmp/custom/custom/lib/libflutter_engine.so.runtime"
rm "$tmp/custom/custom/lib/libflutter_engine.so"
mv "$tmp/custom/custom/lib/libflutter_engine.so.runtime" "$tmp/custom/custom/lib/libflutter_engine.so"
run install "DESTDIR=$tmp/custom" LIBDIR=/custom/lib INSTALL_ENGINE=0
test -L "$tmp/custom/custom/lib/libflutter_engine.so"
cmp "$fixture/engine.so" "$tmp/custom/custom/lib/libflutter_engine.so"

rm "$fixture/lib/libapp.so"
reject install "DESTDIR=$tmp/missing-aot"
reject install FLUTTER_MODE=debug "DESTDIR=$tmp/missing-kernel"
printf 'kernel\n' > "$fixture/data/flutter_assets/kernel_blob.bin"
run install FLUTTER_MODE=debug "DESTDIR=$tmp/debug"
test ! -e "$tmp/debug/usr/local/lib/veshell/libapp.so"
test -f "$tmp/debug/usr/local/share/veshell/data/flutter_assets/kernel_blob.bin"
run install PROFILE=dev "DESTDIR=$tmp/dev"
test ! -e "$tmp/dev/usr/local/lib/veshell/libapp.so"
test -f "$tmp/dev/usr/local/share/veshell/data/flutter_assets/kernel_blob.bin"
printf 'AOT\n' > "$fixture/lib/libapp.so"

reject install PROFILE=custom "DESTDIR=$tmp/custom-profile"
run install PROFILE=custom FLUTTER_MODE=release "DESTDIR=$tmp/custom-profile"
reject check-config ARCH=unsupported APP_LIB= DATA_DIR=
run install ARCH=unsupported "DESTDIR=$tmp/external-arch"
reject check-config INSTALL_ENGINE=invalid

run stage "STAGING_DIR=$tmp/stage" PREFIX=/opt/ignored
test -f "$tmp/stage/usr/bin/veshell"
test -f "$tmp/stage/usr/lib/systemd/user/veshell.service"
test ! -e "$tmp/stage/opt"
reject stage "STAGING_DIR=$tmp/stage"
test -f "$tmp/stage/usr/bin/veshell"
mkdir "$tmp/hidden-stage"
touch "$tmp/hidden-stage/.stale"
reject stage "STAGING_DIR=$tmp/hidden-stage"
test -f "$tmp/hidden-stage/.stale"

# Inspect build exports and cross/profile output selection without compiling.
make -C "$repo" --no-print-directory -n build PROFILE=custom FLUTTER_MODE=profile \
    PREFIX=/usr "DESTDIR=$tmp/never-compiled" CARGO_TARGET_DIR=/custom/target TARGET=aarch64-unknown-linux-gnu > "$tmp/build.log"
grep -F "VESHELL_LIB_DIR='/usr/lib/veshell'" "$tmp/build.log"
grep -F "VESHELL_DATA_DIR='/usr/share/veshell/data'" "$tmp/build.log"
grep -F "VESHELL_DEFAULT_CONFIG_DIR='/usr/share/veshell/settings/default'" "$tmp/build.log"
grep -F "VESHELL_FLUTTER_MODE='profile'" "$tmp/build.log"
grep -F "CARGO_TARGET_DIR='/custom/target'" "$tmp/build.log"
grep -F -- "--profile='custom' --target='aarch64-unknown-linux-gnu'" "$tmp/build.log"
if grep -F "$tmp/never-compiled" "$tmp/build.log"; then exit 1; fi
make -C "$repo" --no-print-directory -n install PROFILE=custom FLUTTER_MODE=release \
    CARGO_TARGET_DIR=/custom/target TARGET=aarch64-unknown-linux-gnu > "$tmp/output.log"
grep -F '/custom/target/aarch64-unknown-linux-gnu/custom/veshell' "$tmp/output.log"
make -C "$repo" --no-print-directory -n build PROFILE=dev > "$tmp/dev-build.log"
grep -F "VESHELL_FLUTTER_MODE='debug'" "$tmp/dev-build.log"
grep -F -- "--profile='dev'" "$tmp/dev-build.log"

# Optional archive check uses the real metadata, but no Veshell dependencies/build.
if [[ "${TEST_ARCHIVES:-0}" == 1 ]]; then
    export PATH="$original_path"
    archive="$tmp/archive"
    mkdir -p "$archive/src"
    cp "$repo/Makefile" "$archive/Makefile"
    printf '%s\n' '[package]' 'name = "veshell-packaging-fixture"' 'version = "0.1.0"' \
        'edition = "2021"' 'description = "Packaging fixture"' 'license = "GPL-3.0-or-later"' \
        'authors = ["Packaging Fixture <fixture@example.invalid>"]' > "$archive/Cargo.toml"
    # Nix ELF dependencies are not Debian packages; dependency discovery is not under test.
    sed -n '/^\[package.metadata.generate-rpm\]/,$p' "$repo/Cargo.toml" | \
        sed '/^\[package.metadata.deb\]/a depends = ""' >> "$archive/Cargo.toml"
    printf 'fn main() {}\n' > "$archive/src/main.rs"
    printf 'int main(void) { return 0; }\n' | "${CC:-cc}" -x c -o "$fixture/veshell" -
    printf 'int fixture(void) { return 0; }\n' | "${CC:-cc}" -x c -shared -fPIC -o "$fixture/engine.so" -
    for lib in libapp.so libplugin.so.1 nested/libnested.so; do
        cp "$fixture/engine.so" "$fixture/lib/$lib"
    done
    make -C "$archive" --no-print-directory stage \
        "BIN=$fixture/veshell" "ENGINE_LIB=$fixture/engine.so" "APP_LIB=$fixture/lib/libapp.so" \
        "DATA_DIR=$fixture/data" "SETTINGS_DIR=$fixture/settings" "ASSETS_DIR=$repo/extra/assets" \
        "SERVICE_OUTPUT=$tmp/archive.service" > "$tmp/archive-install.log" 2>&1 || \
        { cat "$tmp/archive-install.log"; exit 1; }
    CARGO_TARGET_DIR="$tmp/archive-target" cargo deb --manifest-path "$archive/Cargo.toml" \
        --no-build --no-strip --offline --output "$tmp/payload.deb"
    dpkg-deb -x "$tmp/payload.deb" "$tmp/deb-extracted"
    for subtree in bin lib/veshell lib/systemd/user share/veshell share/wayland-sessions share/xdg-desktop-portal; do
        diff -r "$archive/build/package-root/usr/$subtree" "$tmp/deb-extracted/usr/$subtree"
    done
    # DesktopNames is a session-manager extension, not an application desktop key.
    sed '/^DesktopNames=/d' "$tmp/deb-extracted/usr/share/wayland-sessions/veshell.desktop" > "$tmp/session.desktop"
    desktop-file-validate "$tmp/session.desktop"
    printf '%s\n' 'Debian archive contents match the complete staged payload.'
fi
printf '%s\n' 'Packaging installation tests passed.'
