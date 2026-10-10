{
  description = "Veshell — an innovative not-desktop environment built with Flutter and Rust";

  # The Flutter engine packaging (free-explorers/flutter-engine-nix) is evaluated
  # against this exact nixpkgs revision; its default.nix pins the same one.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/774debe7a0d1b496e35677ad955a1011c6ff74f3";

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

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      veshell = import ./default.nix { inherit pkgs; };

      # Default the NixOS module to the flake's tested package; an explicit
      # programs.veshell.package still wins, and the module itself falls back to
      # the caller's pkgs when it is imported directly by path.
      module = { lib, ... }: {
        imports = [ ./nix/module.nix ];
        programs.veshell.package = lib.mkDefault veshell;
      };
    in
    {
      packages.${system} = {
        default = veshell;
        veshell = veshell;
        # Split out so the release workflows can build and push each closure on
        # its own. `engine` is the source pin from flutter-engine-nix.
        engine = veshell.flutterEngine.passthru.sourceBuild;
        runtime = veshell.flutterEngine.passthru.runtime;
        sdk = veshell.flutterSdk;
        shell = veshell.shellBundle;
      };

      overlays.default = final: prev: {
        veshell = import ./default.nix { pkgs = final; };
      };

      nixosModules = {
        default = module;
        veshell = module;
      };
    };
}
