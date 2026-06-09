{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.features.media;
in
{
  options.dotfiles.features.media = {
    enable = lib.mkEnableOption "media playback and media-processing tools";

    programs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "firefox" ];
      description = "Repository program modules enabled with the media feature.";
    };

    mpv = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to configure mpv.";
      };
      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {
          ytdl = true;
          ytdl-format = "bestvideo+bestaudio/best";
          hwdec = "auto-safe";
          force-window = "yes";
          save-position-on-quit = "yes";
          keepaspect-window = "yes";
          auto-window-resize = "yes";
          autofit-large = "80%x80%";
        };
        description = "mpv configuration values.";
      };
    };

    cli = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install media-related command-line tools.";
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          viu
          imagemagick
          tesseract
          zbar
          ffmpeg
          gifski
          yt-dlp
        ];
        description = "Media-related command-line packages.";
      };
    };

    firefoxIntegration = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = config.programs.firefox.enable;
        defaultText = lib.literalExpression "config.programs.firefox.enable";
        description = "Whether to register media-related Firefox native messaging hosts.";
      };
      ff2mpvPackage = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ff2mpv-rust;
        defaultText = lib.literalExpression "pkgs.ff2mpv-rust";
        description = "ff2mpv native messaging host package.";
      };
    };

    mimeApps = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = pkgs.stdenv.isLinux;
        defaultText = lib.literalExpression "pkgs.stdenv.isLinux";
        description = "Whether to register media MIME defaults.";
      };
      defaultApplications = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
        default = {
          "video/*" = "mpv.desktop";
          "image/*" = "mpv.desktop";
          "audio/*" = "mpv.desktop";
        };
        description = "Media default applications registered with xdg.mimeApps.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        dotfiles.programs = lib.genAttrs cfg.programs (_: {
          enable = lib.mkDefault true;
        });
      }

      (lib.mkIf cfg.cli.enable {
        home.packages = cfg.cli.packages;
      })

      (lib.mkIf cfg.mpv.enable {
        programs.mpv = {
          enable = true;
          config = cfg.mpv.settings;
        };
      })

      (lib.mkIf cfg.firefoxIntegration.enable {
        assertions = [
          {
            assertion = config.programs.firefox.enable;
            message = "dotfiles.features.media.firefoxIntegration requires programs.firefox.enable.";
          }
        ];

        programs.firefox.nativeMessagingHosts = [
          cfg.firefoxIntegration.ff2mpvPackage
        ];
      })

      (lib.mkIf cfg.mimeApps.enable {
        assertions = [
          {
            assertion = pkgs.stdenv.isLinux;
            message = "dotfiles.features.media.mimeApps is Linux-only.";
          }
        ];

        xdg.mimeApps = {
          enable = true;
          defaultApplications = cfg.mimeApps.defaultApplications;
        };
      })
    ]
  );
}
