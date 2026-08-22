{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.desktopIntegration;
  terminal = config.dotfiles.features.terminal;
  provider = terminal.selected;
  termCommand = provider.mkCommand {
    inherit (terminal.role.floating) appId;
    wait = true;
  };
  termfilechooserRuntimePath = lib.makeBinPath [
    cfg.termfilechooser.fileManager.package
    provider.package
    pkgs.bash
    pkgs.coreutils
    pkgs.gnused
  ];
  termfilechooserWrapper = pkgs.writeShellScript "termfilechooser-yazi-wrapper" ''
    export TERMCMD=${lib.escapeShellArg termCommand}
    export PATH=${lib.escapeShellArg termfilechooserRuntimePath}
    exec ${cfg.termfilechooser.package}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh "$@"
  '';
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
        default = config.programs.emacs.enable;
        defaultText = lib.literalExpression "config.programs.emacs.enable";
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

    termfilechooser = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = terminal.enable;
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
            assertion = pkgs.stdenv.hostPlatform.isLinux;
            message = "dotfiles.features.desktopIntegration is Linux-only.";
          }
          {
            # TODO: このへんは自動で有効無効にして欲しい
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
          cmd=${termfilechooserWrapper}
          default_dir=$HOME
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
