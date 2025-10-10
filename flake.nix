{
  description = "Development environment with Flutter and Rust";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {self, nixpkgs, ...}:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      overrides = (builtins.fromTOML (builtins.readFile (self + "/rust-toolchain.toml")));
      fonts.packages = with pkgs; [
        roboto
      ];
/* 
      flutterVersion = "edada7c56edf4a183c1735310e123c7f923584f1";

      flutterSources = import ./extra/build/nix/flutter-sources.nix {
        inherit (pkgs) lib stdenv cacert callPackage python312;
        flutterHash = flutterVersion;
      };
      flutterEngine = import ./extra/build/nix/flutter-engine.nix {
        inherit (pkgs) lib stdenv cacert pkg-config clang cmake ninja dart;
        flutterSources = flutterSources;
        engineVersion = flutterVersion;
      };
      flutterBin = import ./extra/build/nix/flutter-bin.nix {
        inherit (pkgs) lib stdenv;
        flutterEngine = flutterEngine;
        flutterSources = flutterSources;
      }; */

      # myflutter = (pkgs.callPackage ./extra/build/nix/flutter/default.nix { useNixpkgsEngine = true; }).stable;
      myflutter = (pkgs.callPackage (pkgs.path + "/pkgs/development/compilers/flutter") { useNixpkgsEngine = true; }).stable;


    in
    {
      devShells.${system}.default = pkgs.mkShell rec{
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
          openssl
          jq
          myflutter
          fontconfig
          libepoxy
          roboto          
        ];

        RUSTC_VERSION = overrides.toolchain.channel;

        # https://github.com/rust-lang/rust-bindgen#environment-variables
        LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
        shellHook = ''
          export PATH=$PATH:''${CARGO_HOME:-~/.cargo}/bin
          export PATH=$PATH:''${RUSTUP_HOME:-~/.rustup}/toolchains/$RUSTC_VERSION-x86_64-unknown-linux-gnu/bin/
          export RUST_BACKTRACE=1
          export FLUTTER_PATH=${myflutter}
          export SKIP_FLUTTER_ENGINE_DOWNLOAD=1

          # Ensure the Flutter tool uses the local engine
          export FLUTTER_ALREADY_LOCKED=1
          export FLUTTER_ROOT="${myflutter}"

          echo "=== Flutter Installation ==="

          # Symlink Flutter SDK
          if [ -d ".flutter_sdk" ] && [ ! -L ".flutter_sdk" ]; then
            echo "Removing existing .flutter_sdk directory..."
            rm -rf .flutter_sdk
          fi
          echo "Linking Flutter SDK..."
          ln -sfn ${myflutter} .flutter_sdk

          echo "=== Version Information ==="
          echo "Flutter version: $(${myflutter}/bin/flutter --local-engine $FLUTTER_ENGINE --local-engine-src-path $FLUTTER_ROOT/engine/src --version --machine | jq -r '.flutterVersion')"
          echo "Dart version: $(${myflutter}/bin/flutter --version --machine | jq -r '.dartSdkVersion')"
          echo "Engine revision: $(${myflutter}/bin/flutter --version --machine | jq -r '.engineRevision')"
          echo "Channel: $(${myflutter}/bin/flutter --version --machine | jq -r '.channel')"
          echo "FLUTTER_LOCAL_ENGINE: $FLUTTER_LOCAL_ENGINE"

          # Debugging information
          echo "FLUTTER_ENGINE: $FLUTTER_ENGINE"
          echo "FLUTTER_ROOT: $FLUTTER_ROOT"
          echo "FLUTTER_LOCAL_ENGINE: $FLUTTER_LOCAL_ENGINE"
          echo "FLUTTER_LOCAL_ENGINE_HOST: $FLUTTER_LOCAL_ENGINE_HOST"

          # Verify the Flutter configuration
          echo "Flutter tool configuration:"
          ${myflutter}/bin/flutter config

          echo "Flutter version information:"
          ${myflutter}/bin/flutter --version
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