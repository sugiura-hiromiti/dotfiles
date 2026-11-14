{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
  backend = cfg.portal.fileChooser.backend;
  backendPackage =
    if backend == "termfilechooser" then cfg.termfilechooser.package else pkgs.xdg-desktop-portal-gtk;
  chooser = "org.freedesktop.impl.portal.FileChooser";
in
{
  imports = [
    (lib.mkRemovedOptionModule
      [ "dotfiles" "features" "desktopIntegration" "portal" "fileChooserBackend" ]
      "Use dotfiles.features.desktopIntegration.portal.fileChooser.backend (termfilechooser, gtk, or null)."
    )
    (lib.mkRemovedOptionModule [ "dotfiles" "features" "desktopIntegration" "termfilechooser" "enable" ]
      "Select dotfiles.features.desktopIntegration.portal.fileChooser.backend; use null to stop this feature's FileChooser contribution."
    )
  ];

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
        description = "Portal desktop configuration name matching the session desktop, or common for portals.conf.";
      };
      fileChooser.backend = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "termfilechooser"
            "gtk"
          ]
        );
        default = "termfilechooser";
        description = ''
          Managed FileChooser backend to install and select. null stops this
          feature's FileChooser contribution; other portal defaults may still
          provide a chooser. The session/system must supply a backend while
          the portal remains enabled. Keyring is owned by the session/system.
          Terminal chooser user configuration is provided separately by Home
          Manager or the user.
        '';
      };
    };

    termfilechooser = {
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
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "dotfiles.features.desktopIntegration is Linux-only.";
      }
    ]
    ++ lib.optionals cfg.portal.enable (
      [
        {
          assertion = config.xdg.portal.enable;
          message = "dotfiles.features.desktopIntegration.portal requires final xdg.portal.enable = true; disable portal.enable to stop its contribution.";
        }
      ]
      ++ lib.optionals (backend != null) [
        {
          assertion = lib.elem (toString backendPackage) (map toString config.xdg.portal.extraPortals);
          message = "dotfiles.features.desktopIntegration.portal.fileChooser.backend requires its selected package in final xdg.portal.extraPortals.";
        }
        {
          assertion = (config.xdg.portal.config.${cfg.portal.configName}.${chooser} or null) == backend;
          message = "dotfiles.features.desktopIntegration.portal.fileChooser.backend conflicts with the final FileChooser setting for ${cfg.portal.configName}; use backend = null to manage it externally.";
        }
      ]
    );

    xdg.portal = lib.mkIf cfg.portal.enable {
      enable = lib.mkDefault true;
      extraPortals = lib.optional (backend != null) backendPackage;
      config.${cfg.portal.configName} = lib.mkIf (backend != null) {
        # Niri with useNautilus=false selects GTK at normal priority. The
        # managed choice must override that default; assertions check the final
        # result even when a caller supplies a stronger override.
        ${chooser} = lib.mkForce backend;
      };
    };
  };
}
