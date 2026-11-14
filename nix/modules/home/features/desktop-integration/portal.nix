{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
  backend = cfg.portal.fileChooser.backend;
  backendPackage =
    if backend == "termfilechooser" then cfg.termfilechooser.package else pkgs.xdg-desktop-portal-gtk;
  chooser = "org.freedesktop.impl.portal.FileChooser";
  policyConfig = {
    default = cfg.portal.defaultBackends;
    "org.freedesktop.impl.portal.Access" = cfg.portal.accessBackend;
    "org.freedesktop.impl.portal.Notification" = cfg.portal.notificationBackend;
    "org.freedesktop.impl.portal.Secret" = cfg.portal.secretBackend;
  };
  policyOptions = {
    default = "defaultBackends";
    "org.freedesktop.impl.portal.Access" = "accessBackend";
    "org.freedesktop.impl.portal.Notification" = "notificationBackend";
    "org.freedesktop.impl.portal.Secret" = "secretBackend";
  };
  portalConfig =
    policyConfig
    // lib.optionalAttrs (backend != null) {
      ${chooser} = backend;
    };
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

  options = {
    dotfiles = {
      features = {
        desktopIntegration = {
          portal = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to configure the user XDG desktop portal.";
            };
            configName = lib.mkOption {
              type = lib.types.str;
              default = "niri";
              description = "Portal desktop configuration name matching the session desktop, or common for portals.conf.";
            };
            defaultBackends = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "gnome"
                "gtk"
              ];
              description = "Default backend selection policy; implementations must be supplied by the session/system.";
            };
            accessBackend = lib.mkOption {
              type = lib.types.str;
              default = "gtk";
              description = "Access backend selection policy; the session/system supplies its implementation.";
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
                Managed FileChooser backend to install, select and configure.
                null stops this feature's FileChooser contribution; shared
                portal defaults may still provide a chooser. Other interfaces
                use backends supplied by the session/system. Standalone Home
                Manager users must provide those services separately.
              '';
            };
            notificationBackend = lib.mkOption {
              type = lib.types.str;
              default = "gtk";
              description = "Notification backend selection policy; the session/system supplies its implementation.";
            };
            secretBackend = lib.mkOption {
              type = lib.types.str;
              default = "gnome-keyring";
              description = ''
                Secret backend selection policy. The session/system supplies
                its implementation; this does not install, start or unlock a keyring.
              '';
            };
          };
        };
      };
    };
  };
  config = lib.mkIf (cfg.enable && cfg.portal.enable) {
    assertions = [
      {
        assertion = config.xdg.portal.enable;
        message = "dotfiles.features.desktopIntegration.portal requires final xdg.portal.enable = true; disable portal.enable to stop its contribution.";
      }
    ]
    ++ lib.mapAttrsToList (interface: value: {
      assertion =
        (config.xdg.portal.config.${cfg.portal.configName}.${interface} or null)
        == (if lib.isList value then lib.concatStringsSep ";" value else value);
      message = "dotfiles.features.desktopIntegration.portal.${policyOptions.${interface}} conflicts with final xdg.portal.config.${cfg.portal.configName}.${interface}; configure the public selection policy instead.";
    }) policyConfig
    ++ lib.optionals (backend != null) [
      {
        assertion = lib.elem (toString backendPackage) (map toString config.xdg.portal.extraPortals);
        message = "dotfiles.features.desktopIntegration.portal.fileChooser.backend requires its selected package in final xdg.portal.extraPortals.";
      }
      {
        assertion = (config.xdg.portal.config.${cfg.portal.configName}.${chooser} or null) == backend;
        message = "dotfiles.features.desktopIntegration.portal.fileChooser.backend conflicts with the final FileChooser setting for ${cfg.portal.configName}; use backend = null to manage it externally.";
      }
    ];
    xdg = {
      portal = {
        enable = lib.mkDefault true;
        extraPortals = lib.optional (backend != null) backendPackage;
        config.${cfg.portal.configName} = portalConfig;
      };
    };
  };
}
