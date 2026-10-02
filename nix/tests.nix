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
in
assert lib.all (item: item.assertion) enabled.assertions;
assert builtins.elem mockPackage enabled.environment.systemPackages;
assert builtins.elem mockPackage enabled.services.displayManager.sessionPackages;
assert builtins.elem mockPackage enabled.systemd.packages;
assert enabled.hardware.graphics.enable;
assert enabled.security.polkit.enable;
assert enabled.security.wrappers.polkit-agent-helper-1.setuid;
assert enabled.services.pipewire.enable;
assert enabled.xdg.portal.config.veshell."org.freedesktop.impl.portal.ScreenCast" == "veshell";
assert enabled.xdg.portal.config.veshell.default == "gtk";
assert !(builtins.elem mockPackage disabled.environment.systemPackages);
assert !(builtins.elem mockPackage disabled.services.displayManager.sessionPackages);
{ moduleChecks = "passed"; }
