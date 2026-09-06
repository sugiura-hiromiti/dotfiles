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
      panel = {
        launcher_placement = "floating";
        clipboard_placement = "floating";
        wallpaper_placement = "floating";
        session_placement = "floating";
      };
    };

    backdrop = {
      enabled = true;
      blur_intensity = 0.5;
      tint_intensity = 0.2;
    };

    bar = {
      main = {
        position = "top";

        # transparent bar container
        background_opacity = 0.0;
        border_width = 0.0;
        shadow = false;
        layer = "overlay";
        font_weight = 200;

        # opaque backgrounds around individual widgets
        capsule = true;
        capsule_fill = "surface_variant";

        margin_edge = 0;
        margin_end = 0;
        widget_spacing = 10;
        thickness = 27;

        auto_hide = false;
        smart_auto_hide = true;
        reserve_space = false;
        # TODO: check properly conditional enabling like brightness
        start = [
          "privacy"
          "launcher"
          "taskbar"
          "media"
        ];
        center = [
        ];
        end = [
          "keyboard_layout"
          "caffeine"
          "battery"
          "network"
          "bluetooth"
          "volume"
          "nightlight"
        ]
        ++ optionals cfg.ddc.enable [
          "brightness"
        ]
        ++ [
          "notification"
          "wallpaper"
          "clock"
        ];
      };
    };

    widget = {
      clock = {
        format = "{:%-m/%-d %a %H:%M}";
      };

      keyboard_layout = {
        hide_when_single_layout = true;
      };
      network = {
        show_vpn_label = true;
      };
      privacy = {
        hide_inactive = true;
      };
      media = {
        artist_first = true;
        hide_when_no_media = true;
      };
      taskbar = {
        group_by_workspace = true;
        workspace_group_content = "icons";
      };
    };

    theme = {
      mode = theme;
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
