{
  description = "Development environment with Flutter and Rust";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {self, nixpkgs, ...}:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      overrides = (builtins.fromTOML (builtins.readFile (self + "/rust-toolchain.toml")));

      flutterEngineDebugHash = "sha256-XNZGEFE7ryNhA9Fc33n0v/uq7+IjdDDAMpqEVECRxws=";
      flutterEngineReleaseHash = "sha256-2BneNQqZQRHCQt5AUHjo2G5qrwwsyRHmvZm9V+Qc/Eo=";

      # Get Flutter SDK
      myflutter = pkgs.flutter332;

      libPath = with pkgs; lib.makeLibraryPath [
        # load external libraries that you need in your rust project here
      ];
    in
    let
      lib = pkgs.lib;  

      engineRevision = myflutter.passthru.engineVersion;

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
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = with pkgs; [
          clang
          llvmPackages.bintools
          rustup
          libGL
          libgbm
          libinput
          libxkbcommon
          cmake
          seatd
          systemd
          wayland
          xwayland
          pulseaudio         
          git
          util-linux
          pixman
          jq
          myflutter
        ];
        RUSTC_VERSION = overrides.toolchain.channel;

        # https://github.com/rust-lang/rust-bindgen#environment-variables
        LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
        shellHook = ''
          export PATH=$PATH:''${CARGO_HOME:-~/.cargo}/bin
          export PATH=$PATH:''${RUSTUP_HOME:-~/.rustup}/toolchains/$RUSTC_VERSION-x86_64-unknown-linux-gnu/bin/
          export RUST_BACKTRACE=1
          export FLUTTER_PATH=${myflutter}
          export FLUTTER_ENGINE_PATH=${flutterEngine}
          export SKIP_FLUTTER_ENGINE_DOWNLOAD=1
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
          echo "Flutter version: $(${myflutter}/bin/flutter --version --machine | jq -r '.flutterVersion')"
          echo "Dart version: $(${myflutter}/bin/flutter --version --machine | jq -r '.dartSdkVersion')"
          echo "Engine revision: $(${myflutter}/bin/flutter --version --machine | jq -r '.engineRevision')"
          echo "Channel: $(${myflutter}/bin/flutter --version --machine | jq -r '.channel')"
          '';

        # Add precompiled library to rustc search path
        RUSTFLAGS = (builtins.map (a: ''-L ${a}/lib'') [
          # add libraries here (e.g. pkgs.libvmi)
        ]);
        
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (buildInputs ++ nativeBuildInputs);
        # Add glibc, clang, glib, and other headers to bindgen search path
        BINDGEN_EXTRA_CLANG_ARGS =
        # Includes normal include path
        (builtins.map (a: ''-I"${a}/include"'') [
          # add dev libraries here (e.g. pkgs.libvmi.dev)
          pkgs.glibc.dev
        ])
        # Includes with special directory paths
        ++ [
          ''-I"${pkgs.llvmPackages_latest.libclang.lib}/lib/clang/${pkgs.llvmPackages_latest.libclang.version}/include"''
          ''-I"${pkgs.glib.dev}/include/glib-2.0"''
          ''-I${pkgs.glib.out}/lib/glib-2.0/include/''
        ];
      };
    };
}
