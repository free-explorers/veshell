# Native release engine using nixpkgs' source engine and local-engine SDK API.
# The content-aware engineVersion is not a Git revision; sourceRev is the
# immutable Flutter release commit whose bin/internal/engine.version matches it.
{
  lib,
  callPackage,
  path,
  stdenv,
  fetchgit,
  dart-bin,
}:
let
  flutterVersion = (builtins.fromTOML (builtins.readFile ../Cargo.toml)).package.metadata.flutter_version;
  pin = (lib.importJSON ./engine-source.json).${flutterVersion}
    or (throw "No source engine metadata for Flutter ${flutterVersion}.");
  sdkPin = (lib.importJSON ./flutter-sdk.json).${flutterVersion};
  enginePath = path + "/pkgs/development/compilers/flutter/engine";
  system = stdenv.hostPlatform.system;
  sourceHash = pin.sourceHashes.${system}.${system};
  # The bootstrap SDK is only a build tool. The exported SDK is engine.dart,
  # compiled with the same Dart sources as libflutter_engine and gen_snapshot.
  bootstrapDart = dart-bin.overrideAttrs (old: {
    version = pin.dartVersion;
    src = old.src.overrideAttrs (_: { hash = sdkPin.dartHash.${system}; });
  });
  sourceCleanup = ''
    find $out -name '.git' -exec rm --recursive --force {} \; || true

    rm --recursive $out/src/flutter/{buildtools,prebuilts,third_party/swiftshader,third_party/gn/.versions,third_party/dart/tools/sdks/dart-sdk}
  '';
  engine = callPackage (enginePath + "/package.nix") {
    callPackage = file: args:
      let
        package = callPackage file args;
      in
      if toString file == toString (enginePath + "/source.nix") then
        package.overrideAttrs (old: {
          # /build and /nix/store can be separate mounts: mv copies before
          # removing its source. Prune discarded data before that peak.
          buildCommand = lib.replaceStrings
            [ "mv engine $out" sourceCleanup ]
            [ ((lib.replaceStrings [ "$out" ] [ "engine" ] sourceCleanup) + "\n    mv engine $out") "" ]
            old.buildCommand;
        })
      else
        package;
    version = pin.engineVersion;
    inherit flutterVersion;
    dartSdkVersion = pin.dartVersion;
    dart = bootstrapDart;
    url = "${pin.sourceUrl}@${pin.sourceRev}";
    hashes.${system}.${system} =
      if sourceHash == null then
        throw "Missing verified source hash for Flutter ${flutterVersion}; complete the source.nix probe before building the engine."
      else
        sourceHash;
    swiftshaderRev = pin.swiftshaderRev;
    swiftshaderHash = pin.swiftshaderHash;
    # GN does not need SwiftShader's CMake/test submodules. In particular,
    # do not clone LLVM only to delete it in nixpkgs' postFetch hook.
    fetchgit = args: fetchgit (args // {
      fetchSubmodules = pin.swiftshaderFetchSubmodules;
    });
    runtimeMode = "release";
    isOptimized = true;
    patches = [ ];
  };
in
assert lib.assertMsg (
  system == "x86_64-linux"
  && stdenv.buildPlatform.system == system
  && stdenv.targetPlatform.system == system
) "Veshell's source engine is pinned only for native x86_64-linux.";
assert lib.assertMsg (
  pin.engineVersion == sdkPin.engineVersion && pin.dartVersion == sdkPin.dartVersion
) "Source engine metadata must match the project Flutter SDK pin.";
engine.overrideAttrs (old: {
  # Keep LTO links serial while allowing parallel compilation.
  configureFlags = old.configureFlags ++ [ "--gn-args=concurrent_toolchain_jobs=1" ];
  NIX_CFLAGS_COMPILE = old.NIX_CFLAGS_COMPILE ++ [ "-Wno-macro-redefined" ];
  postUnpack = lib.replaceStrings
    [ "1111111111111111111111111111111111111111" ]
    [ pin.engineVersion ]
    old.postUnpack;
  buildPhase = lib.replaceStrings
    [ "ninja -C $out/out/host_release -j$NIX_BUILD_CORES" ]
    [ ("ninja -C $out/out/host_release -j$NIX_BUILD_CORES " + lib.concatStringsSep " " [
      "flutter/shell/platform/embedder:flutter_engine"
      "flutter/build/dart:dart_sdk"
      "flutter/flutter_frontend_server:frontend_server"
      "flutter/lib/snapshot:generate_snapshot_bins"
      "flutter/shell/platform/linux:linux"
      "flutter/sky/packages:packages"
      "flutter/impeller/compiler:impellerc"
      "flutter/impeller/tessellator:tessellator_shared"
      "flutter/tools/font_subset:_font-subset"
      "flutter/tools/const_finder:const_finder"
    ]) ]
    old.buildPhase;
  postInstall = (old.postInstall or "") + ''
    install -Dm644 src/flutter/shell/platform/embedder/embedder.h \
      "$out/out/host_release/flutter_embedder.h"
    # GN writes the release kernel into flutter_patched_sdk; Flutter's local
    # release platformKernelDill lookup also expects the product directory name.
    test -s "$out/out/host_release/flutter_patched_sdk/platform_strong.dill"
    ln -s flutter_patched_sdk "$out/out/host_release/flutter_patched_sdk_product"
    test -s "$out/out/host_release/libflutter_engine.so"
    test -x "$out/out/host_release/gen_snapshot"
    "$out/out/host_release/gen_snapshot" --version 2>&1 \
      | grep -F "${pin.dartVersion}"
  '';
  passthru = (old.passthru or { }) // {
    inherit (pin) engineVersion sourceRev;
    inherit sourceHash;
  };
})
