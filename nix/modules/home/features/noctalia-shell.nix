{
  config,
  lib,
  pkgs,
  theme,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    optionals
    types
    ;
  cfg = config.dotfiles.features.noctaliaShell;
  settings = {
    shell = {
      settings_show_advanced = true;
      clipboard_enabled = true;
      clipboard_auto_paste = "auto";
    };

    backdrop = {
      enabled = true;
      blur_intensity = 0.5;
      tint_intensity = 0.2;
    };

    bar.main = {
      position = "right";
      background_opacity = 0.7;
      margin_ends = 10;
      margin_edge = 10;
      auto_hide = true;
      reserve_space = false;
      scale = 1.0;
      start = [
        "launcher"
        "workspaces"
        "sysmon"
        "media"
        "audio_visualizer"
      ];
      center = [
        "clock"
      ];
      end = [
        "notifications"
        "battery"
        "clipboard"
        "volume"
        "wallpaper"
      ]
      ++ optionals cfg.ddc.enable [
        "brightness"
      ];
    };

    shell.panel = {
      launcher_placement = "floating";
      clipboard_placement = "floating";
      wallpaper_placement = "floating";
      session_placement = "floating";
    };

    theme = {
      mode = theme;
      source = "wallpaper";
      builtin = "m3-content";
    };

    notification = {
      background_opacity = 0.7;
    };

    audio = {
      enable_sounds = true;
    };

    brightness = {
      enable_ddcutil = cfg.ddc.enable;
    };

    wallpaper = {
      enabled = true;
      directory = "${config.dotfiles.paths.wallpaperDirectory}/";
      automation = {
        enabled = true;
        interval_seconds = 60;
        order = "random";
        recursive = true;
      };
    };

    calendar = {
      enabled = true;
      refresh_minutes = 1;
      account.my_google = {
        type = "google";
        name = "google";
      };
    };
  };
in
{
  options.dotfiles.features.noctaliaShell = {
    enable = mkEnableOption "Noctalia Shell";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "Noctalia package. Null delegates to the upstream Home Manager module default.";
    };

    ddc.enable = mkEnableOption "Noctalia DDC brightness integration";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "dotfiles.features.noctaliaShell is Linux-only.";
      }
    ];

    home.packages = optionals cfg.ddc.enable [
      pkgs.ddcutil
    ];

    programs.noctalia = {
      enable = true;
      inherit settings;
    }
    // optionalAttrs (cfg.package != null) {
      package = cfg.package;
    };
  };
}
