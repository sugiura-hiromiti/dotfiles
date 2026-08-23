{
  lib,
  config,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
  portalConfig = {
    default = cfg.portal.defaultBackends;
    "org.freedesktop.impl.portal.Access" = cfg.portal.accessBackend;
    "org.freedesktop.impl.portal.Notification" = cfg.portal.notificationBackend;
    "org.freedesktop.impl.portal.Secret" = cfg.portal.secretBackend;
  }
  // lib.optionalAttrs cfg.termfilechooser.enable {
    "org.freedesktop.impl.portal.FileChooser" = cfg.portal.fileChooserBackend;
  };
in
{
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
              description = "Portal desktop configuration name.";
            };
            defaultBackends = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "gnome"
                "gtk"
              ];
              description = "Default portal backends.";
            };
            accessBackend = lib.mkOption {
              type = lib.types.str;
              default = "gtk";
              description = "Portal backend for Access.";
            };
            fileChooserBackend = lib.mkOption {
              type = lib.types.str;
              default = "termfilechooser";
              description = "Portal backend for FileChooser.";
            };
            notificationBackend = lib.mkOption {
              type = lib.types.str;
              default = "gtk";
              description = "Portal backend for Notification.";
            };
            secretBackend = lib.mkOption {
              type = lib.types.str;
              default = "gnome-keyring";
              description = "Portal backend for Secret.";
            };
          };
        };
      };
    };
  };
  config = lib.mkIf (cfg.enable && cfg.portal.enable) {
    xdg = {
      portal = {
        enable = lib.mkDefault true;
        extraPortals = lib.mkIf cfg.termfilechooser.enable [
          cfg.termfilechooser.package
        ];
        config.${cfg.portal.configName} = portalConfig;
      };
    };
  };
}
