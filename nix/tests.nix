# Evaluation checks only: the mock package does not test a graphical session.
{ pkgs ? import <nixpkgs> { } }:
let
  lib = pkgs.lib;
  mockPackage = pkgs.runCommand "veshell-module-test" {
    passthru.providedSessions = [ "veshell" ];
  } "mkdir -p $out";
  evaluate = enabled: import (pkgs.path + "/nixos/lib/eval-config.nix") {
    inherit pkgs;
    modules = [
      ./module.nix
      {
        system.stateVersion = "26.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = { device = "/dev/vda"; fsType = "ext4"; };
        programs.veshell = { enable = enabled; }
          // lib.optionalAttrs enabled { package = mockPackage; };
      }
    ];
  };
  enabled = (evaluate true).config;
  disabled = (evaluate false).config;
  sources = import ./sources.nix { inherit lib; };
  compositorPaths = map toString (lib.fileset.toList sources.compositorFiles);
in
assert lib.all (item: item.assertion) enabled.assertions;
assert builtins.elem mockPackage enabled.environment.systemPackages;
assert builtins.elem mockPackage enabled.services.displayManager.sessionPackages;
assert builtins.elem mockPackage enabled.systemd.packages;
assert enabled.hardware.graphics.enable;
assert enabled.services.upower.enable;
assert enabled.security.polkit.enable;
assert enabled.security.wrappers.polkit-agent-helper-1.setuid;
assert enabled.services.pipewire.enable;
assert enabled.services.pipewire.pulse.enable;
assert enabled.xdg.portal.config.veshell."org.freedesktop.impl.portal.ScreenCast" == "veshell";
assert enabled.xdg.portal.config.veshell.default == "gtk";
assert !(builtins.elem mockPackage disabled.environment.systemPackages);
assert !(builtins.elem mockPackage disabled.services.displayManager.sessionPackages);
assert builtins.elem (toString ../extra/build/mod.rs) compositorPaths;
assert builtins.elem (toString ../src/embedder/resources/cursor.rgba) compositorPaths;
assert builtins.elem (toString ../Makefile) compositorPaths;
assert lib.all (file: !(lib.any (directory: lib.hasPrefix directory file) [
  "${toString ../.}/src/shell/" "${toString ../.}/docs/"
  "${toString ../.}/nix/" "${toString ../.}/.github/"
])) compositorPaths;
assert !(sources.shellFilter "${toString ../.}/src/shell/build" "directory");
assert !(sources.shellFilter "${toString ../.}/src/shell/.dart_tool" "directory");
assert !(sources.shellFilter "${toString ../.}/src/shell/linux/flutter/ephemeral" "directory");
assert !(sources.shellFilter "${toString ../.}/src/shell/lib/generated.g.dart" "regular");
{ moduleChecks = "passed"; sourceChecks = "passed"; }
