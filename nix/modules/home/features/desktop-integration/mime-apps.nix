{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
in
{
  options = {
    dotfiles = {
      features = {
        desktopIntegration = {
          mimeApps = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to configure default XDG MIME applications.";
            };
            defaultApplications = lib.mkOption {
              type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
              default =
                lib.optionalAttrs (config.services.emacs.enable && config.services.emacs.client.enable) {
                  "text/plain" = "emacsclient.desktop";
                }
                // lib.optionalAttrs cfg.orgProtocol.enable {
                  "x-scheme-handler/org-protocol" = "org-protocol.desktop";
                }
                // {
                  "inode/directory" = "yazi.desktop";
                  "text/uri-list" = "yazi.desktop";
                };
              description = "Default applications registered with xdg.mimeApps.";
            };
          };
        };
      };
    };
  };

  config = {
    xdg = {
      mimeApps = {
        enable = true;
        defaultApplications = cfg.mimeApps.defaultApplications;
      };
    };
  }

  ;
}
