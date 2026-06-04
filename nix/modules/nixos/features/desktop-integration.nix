{
  config,
  lib,
  pkgs,
  system,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
in
{
  options.dotfiles.features.desktopIntegration = {
    enable = lib.mkEnableOption "desktop integration";

    portal = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to configure the system XDG desktop portal.";
      };
      configName = lib.mkOption {
        type = lib.types.str;
        default = "niri";
        description = "Portal desktop configuration name.";
      };
      fileChooserBackend = lib.mkOption {
        type = lib.types.str;
        default = "termfilechooser";
        description = "Portal backend for FileChooser.";
      };
    };

    termfilechooser = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to add xdg-desktop-portal-termfilechooser as a system portal.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.xdg-desktop-portal-termfilechooser;
        defaultText = lib.literalExpression "pkgs.xdg-desktop-portal-termfilechooser";
        description = "xdg-desktop-portal-termfilechooser package.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasSuffix "-linux" system;
        message = "dotfiles.features.desktopIntegration is Linux-only.";
      }
    ];

    xdg.portal = lib.mkIf cfg.portal.enable {
      enable = lib.mkDefault true;
      extraPortals = lib.mkIf cfg.termfilechooser.enable [
        cfg.termfilechooser.package
      ];
      config.${cfg.portal.configName} = lib.mkIf cfg.termfilechooser.enable {
        "org.freedesktop.impl.portal.FileChooser" = lib.mkForce cfg.portal.fileChooserBackend;
      };
    };
  };
}
