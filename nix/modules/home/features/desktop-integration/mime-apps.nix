{
  lib,
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
                }
                // lib.optionalAttrs config.programs.qutebrowser.enable {
                  "text/html" = "org.qutebrowser.qutebrowser.desktop";
                  "application/xhtml+xml" = "org.qutebrowser.qutebrowser.desktop";
                  "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
                  "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
                }
                // lib.optionalAttrs config.dotfiles.programs.glide.enable {
                  "text/html" = "glide.desktop";
                  "application/xhtml+xml" = "glide.desktop";
                  "x-scheme-handler/http" = "glide.desktop";
                  "x-scheme-handler/https" = "glide.desktop";
                };
              description = ''
                MIME default selection policy; referenced handlers are supplied
                by their own program/session configuration, not installed or
                validated here. Automatic directory/URI defaults select Yazi;
                Glide takes precedence over Qutebrowser when both are enabled.
                An explicit value replaces the whole automatic default map.
              '';
            };
          };
        };
      };
    };
  };

  config = lib.mkIf (cfg.enable && cfg.mimeApps.enable) {
    xdg = {
      mimeApps = {
        enable = true;
        defaultApplications = cfg.mimeApps.defaultApplications;
      };
    };
  };
}
