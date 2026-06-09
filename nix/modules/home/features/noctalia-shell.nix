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
      clipboard_enabled = cfg.clipboard.enable;
      clipboard_auto_paste = if cfg.clipboard.enable then "auto" else "off";
    };

    bar.main = {
      position = "right";
      background_opacity = 0.3;
      margin_h = 10;
      margin_v = 10;
      auto_hide = true;
      reserve_space = false;
      scale = 1.0;
      start = [
        "launcher"
        "workspaces"
        "system-monitor"
        "media"
      ];
      center = [
        "clock"
      ];
      end = [
        "notifications"
        "battery"
        "volume"
      ]
      ++ optionals cfg.ddc.enable [
        "brightness"
      ]
      ++ optionals cfg.clipboard.enable [
        "clipboard"
      ]
      ++ optionals cfg.wallpaper.enable [
        "wallpaper"
      ];
    };

    shell.panel = {
      launcher_placement = "floating";
      clipboard_placement = "floating";
      wallpaper_placement = "attached";
      session_placement = "attached";
    };

    theme = {
      mode = theme;
      source = "builtin";
      builtin = "Catppuccin";
    };

    notification = {
      background_opacity = 0.3;
    };

    audio = {
      enable_sounds = true;
    };

    brightness = {
      enable_ddcutil = cfg.ddc.enable;
    };
  }
  // optionalAttrs cfg.wallpaper.enable {
    wallpaper = {
      enabled = true;
      directory = "${config.dotfiles.paths.wallpaperDirectory}/";
      automation = {
        enabled = true;
        interval_minutes = 1;
        order = "random";
        recursive = true;
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

    calendar.enable = mkEnableOption "Noctalia calendar integration";
    clipboard.enable = mkEnableOption "Noctalia clipboard history integration";
    ddc.enable = mkEnableOption "Noctalia DDC brightness integration";
    screenToolkit.enable = mkEnableOption "Noctalia screen toolkit helpers";
    visualizer.enable = mkEnableOption "Noctalia audio visualizer integration";
    wallpaper.enable = mkEnableOption "Noctalia wallpaper integration";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "dotfiles.features.noctaliaShell is Linux-only.";
      }
    ];

    home.packages =
      optionals cfg.calendar.enable [
        pkgs.evolution-data-server
      ]
      ++ optionals cfg.clipboard.enable [
        pkgs.wl-clipboard-rs
      ]
      ++ optionals cfg.ddc.enable [
        pkgs.ddcutil
      ]
      ++ optionals cfg.screenToolkit.enable [
        pkgs.grim
        pkgs.slurp
      ];

    dotfiles.programs.cava.enable = mkIf cfg.visualizer.enable true;

    services.cliphist = mkIf cfg.clipboard.enable {
      enable = true;
      clipboardPackage = pkgs.wl-clipboard-rs;
    };

    programs.noctalia = {
      enable = true;
      inherit settings;
    }
    // optionalAttrs (cfg.package != null) {
      package = cfg.package;
    };
  };
}
