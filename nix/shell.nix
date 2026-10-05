# A release Flutter bundle derivation, not a development shell.
# Supply the exact Nix-packaged flutterSdk pinned in Cargo.toml, with Linux
# artifacts available offline. No fallback to nixpkgs' default SDK is allowed.
# pubspecLock is src/shell/pubspec.lock parsed into a Nix attribute set (e.g.
# lib.importJSON of a separately generated JSON file); this avoids IFD.
# gitHashes maps freedesktop_desktop_entry, material_design_icons_flutter and
# ubuntu_session to real fetchgit hashes at their lockfile resolved revisions.
# Hosted dependency hashes are already recorded in pubspec.lock.
# Pass this derivation's output directly as package.nix's shellBundle.
{
  lib,
  runCommand,
  patch,
  gtk3,
  libpulseaudio,
  flutterSdk,
  flutterEngine,
  pubspecLock,
  gitHashes,
  polkitHelperPath ? "/run/wrappers/bin/polkit-agent-helper-1",
}:
let
  manifest = builtins.fromTOML (builtins.readFile ../Cargo.toml);
  # build_resolvers locates sky_engine relative to the resolved Dart executable.
  # A symlink to nixpkgs' standalone Dart silently drops dart:ui from sdk.sum.
  codegenDart = runCommand "veshell-flutter-codegen-dart" { } ''
    mkdir -p "$out/bin/cache/dart-sdk" "$out/bin/cache/pkg"
    cp -rs ${flutterSdk.dart}/. "$out/bin/cache/dart-sdk/"
    chmod u+w "$out/bin/cache/dart-sdk/bin"
    rm "$out/bin/cache/dart-sdk/bin/dart"
    cp ${flutterSdk.dart}/bin/dart "$out/bin/cache/dart-sdk/bin/dart"
    ln -s ${flutterSdk}/bin/cache/pkg/sky_engine "$out/bin/cache/pkg/sky_engine"
    ln -s "$out/bin/cache/dart-sdk/bin/dart" "$out/bin/dart"
  '';
in
assert lib.assertMsg (flutterSdk.version == manifest.package.metadata.flutter_version)
  "Veshell requires the Flutter SDK pinned in Cargo.toml; supply a matching flutterSdk.";
assert lib.assertMsg (
  flutterEngine.engineVersion == flutterSdk.engineVersion
  && flutterEngine.runtimeMode == "release"
  && flutterEngine.outName == "host_release"
) "Veshell's shell requires the matching source-built host_release engine.";
(flutterSdk.buildFlutterApplication.override { flutter = flutterSdk; }) {
  pname = "veshell-shell";
  version = manifest.package.version;
  src = (import ./sources.nix { inherit lib; }).shell;
  inherit pubspecLock gitHashes;
  # Backport Freezed 4's Dart 3.13 parameter fix without upgrading analyzer
  # beyond the versions supported by the locked custom_lint dependencies.
  customSourceBuilders.freezed = { src, version, ... }:
    runCommand "pub-freezed-${version}-dart-3.13" {
      nativeBuildInputs = [ patch ];
      passthru = src.passthru;
    } ''
      cp -r ${src} "$out"
      chmod -R u+w "$out"
      patch -d "$out" -p1 < ${../extra/build/freezed-dart-3.13.patch}
    '';
  flutterMode = "release";
  # Select the source-built frontend, patched SDK and gen_snapshot together;
  # official SDK artifacts must never compile the production AOT snapshot.
  flutterBuildFlags = [
    "--no-pub"
    "--local-engine-src-path=${flutterEngine.sourceBuild}"
    "--local-engine=host_release"
    "--local-engine-host=host_release"
    "--dart-define=VESHELL_POLKIT_HELPER_PATH=${polkitHelperPath}"
  ];
  buildInputs = [ gtk3 libpulseaudio ];

  preBuild = ''
    export PATH="${codegenDart}/bin:$PATH"
    # The offline package-config hook does not run pub's plugin-link setup.
    mkdir -p linux/flutter/ephemeral/.plugin_symlinks
    ln -s "$(packagePath pulseaudio)" linux/flutter/ephemeral/.plugin_symlinks/pulseaudio
    packageRun build_runner build --delete-conflicting-outputs
  '';
  installPhase = ''
    runHook preInstall
    bundles=(build/linux/*/release/bundle)
    test "''${#bundles[@]}" -eq 1
    test -f "''${bundles[0]}/lib/libapp.so"
    mkdir -p "$out"
    cp -r "''${bundles[0]}/lib" "''${bundles[0]}/data" "$out/"
    # The GTK runner is discarded; Veshell uses the independent embedder engine.
    rm "$out/lib/libflutter_linux_gtk.so"
    runHook postInstall
  '';
  doCheck = false;
  meta = {
    description = "Veshell release shell assets and AOT libraries";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
