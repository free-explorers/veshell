{ config, lib, pkgs, ... }:
let
  cfg = config.programs.veshell;
in
{
  options.programs.veshell = {
    enable = lib.mkEnableOption "the Veshell Wayland session";
    package = lib.mkOption {
      type = lib.types.package;
      default = import ../default.nix { inherit pkgs; };
      defaultText = lib.literalExpression "import ../default.nix { inherit pkgs; }";
      description = "Veshell package built with its matching Flutter shell and engine.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    fonts.packages = [ pkgs.roboto pkgs.noto-fonts pkgs.noto-fonts-cjk-sans ];
    services.displayManager.sessionPackages = [ cfg.package ];
    systemd.packages = [ cfg.package ];
    hardware.graphics.enable = true;
    services.dbus.enable = true;
    services.upower.enable = true;
    security.polkit.enable = true;
    security.wrappers.polkit-agent-helper-1 = {
      source = "${config.security.polkit.package.out}/lib/polkit-1/polkit-agent-helper-1";
      owner = "root";
      group = "root";
      setuid = true;
    };
    services.pipewire = {
      enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
      wireplumber.enable = lib.mkDefault true;
    };
    xdg.portal = {
      enable = true;
      extraPortals = [ cfg.package pkgs.xdg-desktop-portal-gtk ];
      config.veshell = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "veshell" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "veshell" ];
      };
    };
  };
}
