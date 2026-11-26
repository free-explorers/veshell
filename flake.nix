{
  description = "Veshell — an innovative not-desktop environment built with Flutter and Rust";

  # The Flutter SDK and shell bundle build on this nixpkgs, and the flake's own
  # packages entirely; the module and the overlay build the compositor with the
  # system's (see veshellFor).
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  # The engine keeps the nixpkgs flutter-engine-nix locks: the veshell cache
  # holds the engine built from that one only, so this input must not follow
  # Veshell's nixpkgs.
  inputs.flutter-engine-nix.url = "github:free-explorers/flutter-engine-nix";

  # Engine, SDK, shell and package closures are published here by the release
  # workflows, so `nix run` / `nix profile add` substitute instead of compiling
  # the Flutter engine. Nix applies a flake's substituters only when flake
  # configuration is accepted; docs/nixos.md shows the manual equivalent.
  nixConfig = {
    extra-substituters = [ "https://veshell.cachix.org" ];
    extra-trusted-public-keys = [
      "veshell.cachix.org-1:C8J71PCJ1Fx4+4shICPNsSOnGgijVEHZCTrWhbYyjOI="
    ];
  };

  outputs = { self, nixpkgs, flutter-engine-nix }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (flutter-engine-nix.lib) engineFor;
      buildCommit = self.rev or self.dirtyRev or null;

      # The compositor loads the system's graphics driver (Mesa from
      # /run/opengl-driver) into its own process, so it must be built with the
      # system's nixpkgs: a driver built against a newer glibc than the
      # compositor's fails to load, and EGL then finds no platform at all. The
      # Flutter SDK and shell bundle stay on this flake's nixpkgs, which their
      # packaging is verified against; the engine has its own pin.
      veshellFor =
        hostPkgs:
        import ./default.nix {
          pkgs = hostPkgs;
          flutterPkgs = pkgs;
          inherit buildCommit engineFor;
        };
      veshell = veshellFor pkgs;

      # The engine for a runtime mode. release is what the package uses; debug
      # and profile are compiled on demand for development. Nix only builds a
      # mode when something asks for it, so nothing is spent unless it is used.
      enginePackages = mode: pkgs.callPackage ./nix/engine.nix {
        inherit engineFor;
        runtimeMode = mode;
      };

      # Default the NixOS module to a compositor built with the system's own
      # nixpkgs (see veshellFor); an explicit programs.veshell.package still
      # wins, and the module itself falls back to the caller's pkgs when it is
      # imported directly by path.
      module =
        { lib, pkgs, ... }:
        {
          imports = [ ./nix/module.nix ];
          programs.veshell.package = lib.mkDefault (veshellFor pkgs);
        };
    in
    {
      packages.${system} = {
        default = veshell;
        veshell = veshell;
        # The source-built engine alone, so the one expensive piece can be
        # pre-built with `nix build .#engine`. The app itself builds in minutes.
        engine = veshell.flutterEngine.passthru.sourceBuild;
        engine-debug = (enginePackages "debug").engine;
        engine-profile = (enginePackages "profile").engine;
      };

      overlays.default = final: _prev: {
        veshell = veshellFor final;
      };

      nixosModules = {
        default = module;
        veshell = module;
      };

      # Dependency-complete development shell for `nix develop` + `cargo run`.
      # The repository build still drives everything; the pinned SDK and source
      # engine are linked in when available so that it does not have to clone
      # the Flutter repository or download meta-flutter's engine.
      devShells.${system} =
        let
          mkDevShell = mode:
            let
              runtime = (enginePackages mode).runtime;
            in
            pkgs.mkShell {
              packages = with pkgs; [
                cargo rustc rustfmt clippy
                pkg-config cmake ninja clang git unzip xz zstd
                wayland libinput libdisplay-info seatd libgbm libxkbcommon pixman
                udev openssl pam pipewire gst_all_1.gstreamer gst_all_1.gst-plugins-base
                gtk3 libpulseaudio libGL libepoxy vulkan-loader fontconfig
              ];
              env = {
                # Selects the bundle the repository build produces and the engine
                # linked below; `nix develop .#debug` compiles the debug engine.
                VESHELL_FLUTTER_MODE = mode;
                SKIP_FLUTTER_ENGINE_DOWNLOAD = "1";
                LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
                LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
                  pkgs.wayland
                  pkgs.libGL
                  pkgs.libpulseaudio
                ];
              };
              shellHook = ''
                # Link the pinned SDK when it exposes the `version` file the build
                # checks; otherwise the recipe's own `git clone` flow installs it.
                if [ ! -e .flutter_sdk ] && [ -f ${veshell.flutterSdk}/version ]; then
                  ln -sfn ${veshell.flutterSdk} .flutter_sdk
                fi
                engine_dir=extra/third_party/flutter_engine
                mkdir -p "$engine_dir/${mode}"
                ln -sfn ${runtime}/lib/libflutter_engine.so "$engine_dir/${mode}/libflutter_engine.so"
                ln -sfn ${runtime}/include/flutter_embedder.h "$engine_dir/flutter_embedder.h"
                echo "Veshell dev shell (${mode}): run 'cargo run'."
              '';
            };
        in
        {
          # Development defaults to a debug engine (JIT), matching `cargo run`'s
          # default profile. Installs — the package, `nix run` and the NixOS
          # module — use the release engine.
          default = mkDevShell "debug";
          debug = mkDevShell "debug";
          release = mkDevShell "release";
          profile = mkDevShell "profile";
        };
    };
}
