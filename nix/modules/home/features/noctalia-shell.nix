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

    accessibility = {
      ui_scale = 2.5;
    };

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
      scale = 2.5;
      position = "right";

      # transparent bar container
      background_opacity = 0.0;
      border_width = 0.0;
      shadow = false;

      # opaque backgrounds around individual widgets
      capsule = true;
      capsule_fill = "surface_variant";
      capsule_opacity = 1.0;
      capsule_thickness = 1.0;
      capsule_padding = 6;
      capsule_radius = 5;

      margin_ends = 10;
      margin_edge = 1;
      widget_spacing = 10;
      thickness = 61;

      auto_hide = false;
      reserve_space = true;
      start = [
        "launcher"
        "workspaces"
        "sysmon"
        # "media"
        # "audio_visualizer"
      ];
      center = [
      ];
      end = [
        "clock"
        # "notifications"
        "battery"
        # "clipboard"
        "volume"
        "wallpaper"
      ]
      ++ optionals cfg.ddc.enable [
        "brightness"
      ];
    };

    widget = {
      # launcher = { };
      # workspaces ={};
      sysmon = {
        capsule_fill = "primary";
        capsule_foreground = "on_primary";
        capsule_border = "on_primary";
      };
      clock = {
        capsule_fill = "secondary";
        capsule_foreground = "on_secondary";
        capsule_border = "on_secondary";
      };
      battery = {
        capsule_fill = "tertiary";
        capsule_foreground = "on_tertiary";
        capsule_border = "on_tertiary";
      };
      volume = {
        capsule_fill = "error";
        capsule_foreground = "on_error";
        capsule_border = "on_error";
      };
      wallpaper = {
        capsule_fill = "surface";
        capsule_foreground = "on_surface";
        capsule_border = "on_surface";
      };
      brightness = {
        capsule_fill = "surface_variant";
        capsule_foreground = "on_surface_variant";
        capsule_border = "on_surface_variant";
      };
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
      layer = "overlay";
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
      # minimum amount is 5
      refresh_minutes = 5;
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
      inherit (cfg) package;
    };
  };
}
