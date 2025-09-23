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
      flutterEngineDebugHash = "sha256-XNZGEFE7ryNhA9Fc33n0v/uq7+IjdDDAMpqEVECRxws=";
      flutterEngineReleaseHash = "sha256-2BneNQqZQRHCQt5AUHjo2G5qrwwsyRHmvZm9V+Qc/Eo=";

      libPath = with pkgs; lib.makeLibraryPath [
        # load external libraries that you need in your rust project here
      ];
    in
    let
      lib = pkgs.lib;  

      # Get Flutter Engine from GitHub
      flutterEngine = pkgs.stdenv.mkDerivation rec {
         pname = "flutter-engine";
          version = "master";

          src = pkgs.fetchFromGitHub {
            owner = "flutter";
            repo = "engine";
            rev = "master";
            # Optionally specify commit hash instead of "master" for reproducibility
            sha256 = "0000000000000000000000000000000000000000000000000000"; # replace with actual sha256
          };

          nativeBuildInputs = [
            pkgs.git
            pkgs.python3
            pkgs.bash
            pkgs.cmake
            pkgs.ninja
          ];

          buildInputs = [
            pkgs.pkg-config
            pkgs.libdrm
            pkgs.libpng
            pkgs.freetype
            pkgs.glib
            pkgs.cairo
            pkgs.fontconfig
            pkgs.libxrandr
            pkgs.libxinerama
            pkgs.libxcursor
            pkgs.libxi
            pkgs.libxcomposite
            pkgs.libxdamage
            pkgs.libxfixes
            pkgs.xorg.xprop
            pkgs.chrome-gn
          ];

          buildPhase = ''
            ./flutter/tools/gn --unoptimized --no-lto --no-goma
            ninja -C out/host_debug_unopt
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp -r out/host_debug_unopt/* $out/bin/
          '';

          meta = with pkgs.lib; {
            description = "Standalone build of the Flutter engine";
            license = licenses.bsd3;
            platforms = platforms.linux;
            maintainers = with maintainers; [ ];
          };
        };
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
        ];

        RUSTC_VERSION = overrides.toolchain.channel;

        # https://github.com/rust-lang/rust-bindgen#environment-variables
        LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
        shellHook = ''
          export PATH=$PATH:''${CARGO_HOME:-~/.cargo}/bin
          export PATH=$PATH:''${RUSTUP_HOME:-~/.rustup}/toolchains/$RUSTC_VERSION-x86_64-unknown-linux-gnu/bin/
          export VPYTHON_VIRTUALENV_ROOT=./vpython
          export RUST_BACKTRACE=1

           # Symlink Flutter Engine
          echo "Linking Flutter Engine..."
          enginePath="build/engine/"
          mkdir -p "$enginePath/debug" "$enginePath/release"
          ln -sf "${flutterEngine}/debug/lib/libflutter_engine.so" "$enginePath/debug/libflutter_engine.so"
          ln -sf "${flutterEngine}/release/lib/libflutter_engine.so" "$enginePath/release/libflutter_engine.so"
          ln -sf "${flutterEngine}/debug/include/flutter_embedder.h" "$enginePath/flutter_embedder.h"
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
