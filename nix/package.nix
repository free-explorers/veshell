# Call with explicit flutterSdk, shellBundle, flutterEngine and cargoHash.
# flutterSdk must match Cargo.toml; the bundle and engine must be built from
# that SDK's engine revision for the host architecture, in release mode.
# shellBundle contains lib/libapp.so and data/{icudtl.dat,flutter_assets}.
# flutterEngine contains flutter_embedder.h and release/libflutter_engine.so.
# cargoHash is the real fetchCargoVendor hash for Cargo.lock (including Smithay).
# It is deliberately mandatory: no dependencies are fetched during evaluation
# and no placeholder hashes or alternate Flutter versions are supplied here.
# Requires the offline build-script inputs VESHELL_PREBUILT_SHELL and
# VESHELL_ENGINE_DIR, and compile-time VESHELL_DATA_DIR support in the source.
{
  lib,
  stdenv,
  rustPlatform,
  pkg-config,
  makeWrapper,
  autoPatchelfHook,
  wayland,
  libinput,
  seatd,
  libgbm,
  libGL,
  libepoxy,
  libxkbcommon,
  pixman,
  udev,
  openssl,
  pipewire,
  gst_all_1,
  gtk3,
  fontconfig,
  libpulseaudio,
  vulkan-loader,
  xwayland,
  systemd,
  dbus,
  xdg-utils,
  bash,
  coreutils,
  gnugrep,
  gawk,
  procps,
  flutterSdk,
  shellBundle,
  flutterEngine,
  cargoHash,
}:
let
  manifest = builtins.fromTOML (builtins.readFile ../Cargo.toml);
  runtimeLibraries = [
    libGL
    vulkan-loader
    libpulseaudio
    fontconfig
    gtk3
    libepoxy
    stdenv.cc.cc.lib
  ];
  runtimePrograms = [
    xwayland
    systemd
    dbus
    xdg-utils
    fontconfig
    bash
    coreutils
    gnugrep
    gawk
    procps
  ];
in
assert lib.assertMsg (flutterSdk.version == manifest.package.metadata.flutter_version)
  "Veshell requires the Flutter SDK pinned in Cargo.toml; supply a matching flutterSdk.";
assert lib.assertMsg (cargoHash != "") "Veshell requires a real cargoHash.";
rustPlatform.buildRustPackage {
  pname = "veshell";
  version = manifest.package.version;

  src = lib.cleanSourceWith {
    src = ../.;
    filter = path: type:
      lib.cleanSourceFilter path type
      && !(type == "directory" && builtins.elem (builtins.baseNameOf path) [
        ".flutter_sdk" "build" "target" ".dart_tool"
      ]);
  };
  inherit cargoHash;

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
    makeWrapper
    autoPatchelfHook
  ];
  buildInputs = [
    wayland
    libinput
    seatd
    libgbm
    libxkbcommon
    pixman
    udev
    openssl
    pipewire
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
  ] ++ runtimeLibraries;

  # Tests require a session bus and graphical/seat resources.
  doCheck = false;
  strictDeps = true;

  preBuild = ''
    export CARGO_TARGET_DIR="$PWD/target"
    test -f ${flutterEngine}/flutter_embedder.h
    test -f ${flutterEngine}/release/libflutter_engine.so
    test -f ${shellBundle}/lib/libapp.so
    test -f ${shellBundle}/data/icudtl.dat
    test -d ${shellBundle}/data/flutter_assets
    export VESHELL_PREBUILT_SHELL=${shellBundle}
    export VESHELL_ENGINE_DIR=${flutterEngine}
    export VESHELL_LIB_DIR="$out/lib/veshell"
    export VESHELL_DATA_DIR="$out/share/veshell/data"
    export VESHELL_DEFAULT_CONFIG_DIR="$out/share/veshell/settings/default"
  '';

  installPhase = ''
    runHook preInstall
    make package PREFIX="$out" PROFILE=release \
      BIN="target/${stdenv.hostPlatform.rust.rustcTarget}/release/veshell" \
      ENGINE_LIB="${flutterEngine}/release/libflutter_engine.so" \
      APP_LIB="${shellBundle}/lib/libapp.so" DATA_DIR="${shellBundle}/data" \
      SYSTEMD_USER_DIR="$out/lib/systemd/user"
    # Preserve native plugin libraries, not just the AOT app library.
    cp -a ${shellBundle}/lib/. "$out/lib/veshell/"
    chmod -R u+w "$out/lib/veshell"
    substituteInPlace "$out/share/wayland-sessions/veshell.desktop" \
      --replace-fail 'Exec=veshell-session' "Exec=$out/bin/veshell-session"
    substituteInPlace "$out/bin/veshell-session" \
      --replace-fail '#!/bin/sh' '#!${bash}/bin/bash'
    patchShebangs "$out/bin"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/veshell" \
      --set VESHELL_DEFAULT_CONFIG_DIR "$out/share/veshell/settings/default" \
      --prefix PATH : ${lib.makeBinPath runtimePrograms} \
      --prefix LD_LIBRARY_PATH : "$out/lib/veshell:/run/opengl-driver/lib:${lib.makeLibraryPath runtimeLibraries}" \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" [ gst_all_1.gst-plugins-base gst_all_1.gst-plugins-good ]}"
    for program in veshell-session veshell-session-stop; do
      wrapProgram "$out/bin/$program" \
        --prefix PATH : "$out/bin:${lib.makeBinPath runtimePrograms}"
    done
  '';

  passthru = {
    inherit flutterSdk shellBundle flutterEngine;
    providedSessions = [ "veshell" ];
  };
  meta = {
    description = manifest.package.description;
    homepage = manifest.package.repository;
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "veshell";
  };
}
