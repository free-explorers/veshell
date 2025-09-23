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

      # Get Flutter SDK
      myflutter = pkgs.flutter332;

      libPath = with pkgs; lib.makeLibraryPath [
        # load external libraries that you need in your rust project here
      ];
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
          CLANG_ROOT=$(find -iname clang++)
          CLANG_ROOT=$(dirname $CLANG_ROOT)
          export CLANG_ROOT=$(dirname $CLANG_ROOT)
          export RUST_BACKTRACE=1
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
