{
  config,
  lib,
  pkgs,
  system,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
  terminalCommand =
    if cfg.termfilechooser.terminal.command != null then
      cfg.termfilechooser.terminal.command
    else
      "${lib.getExe cfg.termfilechooser.terminal.package} start --always-new-process";
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
  options.dotfiles.features.desktopIntegration = {
    enable = lib.mkEnableOption "desktop integration";

    orgProtocol = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to register org-protocol URL handling.";
      };
      emacsPackage = lib.mkOption {
        type = lib.types.package;
        default = config.programs.emacs.finalPackage;
        defaultText = lib.literalExpression "config.programs.emacs.finalPackage";
        description = "Emacs package that provides emacsclient for org-protocol.";
      };
    };

    mimeApps = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to configure default XDG MIME applications.";
      };
      defaultApplications = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
        default = {
          "x-scheme-handler/org-protocol" = "org-protocol.desktop";
          "inode/directory" = "yazi.desktop";
          "text/uri-list" = "yazi.desktop";
        };
        description = "Default applications registered with xdg.mimeApps.";
      };
    };

    termfilechooser = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to configure xdg-desktop-portal-termfilechooser.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.xdg-desktop-portal-termfilechooser;
        defaultText = lib.literalExpression "pkgs.xdg-desktop-portal-termfilechooser";
        description = "xdg-desktop-portal-termfilechooser package.";
      };
      fileManager.package = lib.mkOption {
        type = lib.types.package;
        default = config.programs.yazi.package;
        defaultText = lib.literalExpression "config.programs.yazi.package";
        description = "File manager package used by the terminal file chooser wrapper.";
      };
      terminal = {
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.wezterm;
          defaultText = lib.literalExpression "pkgs.wezterm";
          description = "Terminal package used by the terminal file chooser.";
        };
        command = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Terminal command used by termfilechooser. Null derives it from terminal.package.";
        };
      };
    };

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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = lib.hasSuffix "-linux" system;
            message = "dotfiles.features.desktopIntegration is Linux-only.";
          }
          {
            assertion = !cfg.orgProtocol.enable || config.programs.emacs.enable;
            message = "dotfiles.features.desktopIntegration.orgProtocol requires programs.emacs.enable.";
          }
        ];
      }

      (lib.mkIf cfg.orgProtocol.enable {
        xdg.desktopEntries.org-protocol = {
          name = "org-protocol";
          comment = "handle org-protocol:// urls with emacsclient";
          exec = "${cfg.orgProtocol.emacsPackage}/bin/emacsclient -n -- %u";
          terminal = false;
          type = "Application";
          categories = [ "Utility" ];
          mimeType = [ "x-scheme-handler/org-protocol" ];
        };
      })

      (lib.mkIf cfg.mimeApps.enable {
        xdg.mimeApps = {
          enable = true;
          defaultApplications = cfg.mimeApps.defaultApplications;
        };
      })

      (lib.mkIf cfg.termfilechooser.enable {
        xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
          [filechooser]
          cmd=${cfg.termfilechooser.package}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
          default_dir=$HOME
          env=TERMCMD=${terminalCommand}
              PATH=${
                lib.makeBinPath [
                  cfg.termfilechooser.fileManager.package
                  pkgs.coreutils
                  pkgs.gnused
                ]
              }
          open_mode=suggested
          save_mode=suggested
        '';
      })

      (lib.mkIf cfg.portal.enable {
        xdg.portal = {
          enable = lib.mkDefault true;
          extraPortals = lib.mkIf cfg.termfilechooser.enable [
            cfg.termfilechooser.package
          ];
          config.${cfg.portal.configName} = portalConfig;
        };
      })
    ]
  );
}
