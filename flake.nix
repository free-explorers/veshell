{
  description = "Development environment with Flutter and Rust";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      flutterEngineDebugHash = "sha256-XNZGEFE7ryNhA9Fc33n0v/uq7+IjdDDAMpqEVECRxws=";
      flutterEngineReleaseHash = "sha256-2BneNQqZQRHCQt5AUHjo2G5qrwwsyRHmvZm9V+Qc/Eo=";

      # Get Flutter SDK
      flutter = pkgs.flutter332;
    in
    let
      lib = pkgs.lib;  

      engineRevision = flutter.passthru.engineVersion;

      # Get Flutter Engine from GitHub
      flutterEngine = pkgs.stdenv.mkDerivation rec {
        pname = "flutter-engine";
        version = engineRevision;

        src = pkgs.linkFarm "flutter-engine-src-${version}" (
          lib.listToAttrs (map (cfg: with cfg; {
            name = "${variant}.tar.gz";
            value = pkgs.fetchurl {
              name = "flutter-engine-${variant}-${version}.tar.gz";
              url = "https://github.com/meta-flutter/flutter-engine/releases/download/linux-engine-sdk-${variant}-x86_64-${version}/linux-engine-sdk-${variant}-x86_64-${version}.tar.gz";
              sha256 = hash;
            };
          }) [
            {variant = "debug"; hash = flutterEngineDebugHash;}
            {variant = "release"; hash = flutterEngineReleaseHash;}
          ])
        );

        nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];

        unpackPhase = ''
          runHook preUnpack
          mkdir -p $out/debug $out/release

          tar -xzf $src/debug.tar.gz
          mv flutter/engine/src/out/linux_debug_x64/engine-sdk/* $out/debug/
          rm -rf flutter
          tar -xzf $src/release.tar.gz
          mv flutter/engine/src/out/linux_release_x64/engine-sdk/* $out/release/

          runHook postUnpack
        '';
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = (with pkgs; [
          clang
          cmake
          pkg-config
          rustc
          cargo
          rustfmt
          clippy
          rust-analyzer
          sysprof
          libsysprof-capture
          pcre2
          openssl
          systemd
          seatd
          unzip
          jq
          git
          libxkbcommon
          libinput
          libgbm
          xwayland
          pulseaudio
          util-linux
          libselinux
          libsepol
          libthai
          libdatrie
          xorg.libXdmcp
          xorg.libXtst
          libdeflate
          lerc
          xz
          zstd
          libwebp
          pixman
        ]) ++ [flutter];

        shellHook = ''
          export RUST_BACKTRACE=1
          export SKIP_FLUTTER_ENGINE_DOWNLOAD=1
          export FLUTTER_PATH=${flutter}
          export FLUTTER_ENGINE_PATH=${flutterEngine}
          export LIBCLANG_PATH=${pkgs.libclang.lib}/lib
          export LD_LIBRARY_PATH=${pkgs.wayland}/lib:${pkgs.pulseaudio}/lib:${pkgs.fontconfig.lib}/lib

          echo "=== Flutter Installation ==="

          # Symlink Flutter SDK
          if [ -d ".flutter_sdk" ] && [ ! -L ".flutter_sdk" ]; then
            echo "Removing existing .flutter_sdk directory..."
            rm -rf .flutter_sdk
          fi
          echo "Linking Flutter SDK..."
          ln -sfn ${flutter} .flutter_sdk

          # Symlink Flutter Engine
          echo "Linking Flutter Engine..."
          enginePath="extra/third_party/flutter_engine"
          mkdir -p "$enginePath/debug" "$enginePath/release"
          ln -sf "${flutterEngine}/debug/lib/libflutter_engine.so" "$enginePath/debug/libflutter_engine.so"
          ln -sf "${flutterEngine}/release/lib/libflutter_engine.so" "$enginePath/release/libflutter_engine.so"
          ln -sf "${flutterEngine}/debug/include/flutter_embedder.h" "$enginePath/flutter_embedder.h"

          echo "=== Version Information ==="
          echo "Flutter version: $(${flutter}/bin/flutter --version --machine | jq -r '.flutterVersion')"
          echo "Dart version: $(${flutter}/bin/flutter --version --machine | jq -r '.dartSdkVersion')"
          echo "Engine revision: $(${flutter}/bin/flutter --version --machine | jq -r '.engineRevision')"
          echo "Channel: $(${flutter}/bin/flutter --version --machine | jq -r '.channel')"
        '';
      };
    };
}
