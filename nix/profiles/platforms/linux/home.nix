{
  pkgs,
  accountName,
  account ? { },
  lib,
  ...
}:
let
  configuredHomeDirectory = account.homeDirectory or null;
  homeDir =
    if configuredHomeDirectory != null then configuredHomeDirectory else "/home/${accountName}";
in
{
  home = {
    homeDirectory = lib.mkDefault homeDir;
    sessionVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.so";
  };
  programs.nushell.environmentVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.so";

  # progerams = {
  # niri = {
  #   enable = true;
  #   package = pkgs.niri-unstable;
  #   settings = {
  #     input = {
  #       keyboard = {
  #         repeat-delay = 40000;
  #         repeat-rate = 250;
  #       };
  #       touchpad = {
  #         accel-speed = 1;
  #         accel-profile = "adaptive";
  #         scroll-factor = 2;
  #       };
  #       mouse = {
  #         natural-scroll = true;
  #       };
  #       warp-mouse-to-focus = {
  #         enable = true;
  #         mode = "center-xy-always";
  #       };
  #       focus-follows-mouse = {
  #         enable = true;
  #       };
  #     };
  #     outputs = {
  #       "Virtual-1" = {
  #         mode = {
  #           width = 3840;
  #           height = 2160;
  #           refresh = 59.996;
  #         };
  #         scale = 1;
  #         background-color = "#1f1e33";
  #         position = {
  #           x = 0;
  #           y = 0;
  #         };
  #       };
  #     };
  #     layout = {
  #       gaps = 4;
  #       always-center-single-column = true;
  #       empty-workspace-above-first = true;
  #       preset-column-widths = [
  #         { proportion = 0.33333; }
  #         { proportion = 0.5; }
  #         { proportion = 0.66667; }
  #         { proportion = 1.0; }
  #       ];
  #       default-column-width = {
  #         proportion = 0.33333;
  #       };
  #       focus-ring = {
  #         width = 2;
  #         active = {
  #           gradient = {
  #             from = "#77c5ff";
  #             to = "#bf6300";
  #           };
  #         };
  #         inactive = {
  #           gradient = {
  #             from = "#000000";
  #             to = "#ffffff";
  #             relative-to = "workspace-view";
  #           };
  #         };
  #         urgent = {
  #           color = "#9b0000";
  #         };
  #       };
  #       border = {
  #         active = {
  #           color = "#ffc87f";
  #         };
  #         inactive = {
  #           color = "#ffc";
  #         };
  #         urgent = {
  #           color = "#9b0000";
  #         };
  #       };
  #     };
  #     tab-indicator = {
  #       position = "bottom";
  #       gaps-between-tabs = 5;
  #       corner-radius = 2;
  #       width = 4;
  #       gap = -10;
  #     };
  #     spawn-at-startup = [
  #       { argv = [ "firefox" ]; }
  #       {
  #         argv = [
  #           "wezterm"
  #           "start"
  #           "--class"
  #           "custom.term"
  #         ];
  #       }
  #     ];
  #     hotkey-overlay = {
  #       skip-at-startup = true;
  #     };
  #     cursor = {
  #       size = 22;
  #     };
  #     prefer-no-csd = true;
  #     screenshot-path = "~/Downloads/media/screenshots/%Y%m%d-%H%M%S.png";
  #     workspaces = {
  #       "main" = { };
  #     };
  #     window-rules = [
  #       {
  #         matches = [
  #           {
  #             app-id = "firefox$";
  #             title = "^Picture-in-Picture$";
  #           }
  #           { app-id = "^mpv$"; }
  #         ];
  #         open-floating = true;
  #         open-focused = false;
  #         default-floating-position = {
  #           relative-to = "bottom-left";
  #           x = 0;
  #           y = 0;
  #         };
  #       }
  #       {
  #         matches = [ { is-active = false; } ];
  #         opacity = 0.9;
  #       }
  #       {
  #         matches = [
  #           {
  #             at-startup = true;
  #             app-id = "^custom.term$";
  #           }
  #           {
  #             at-startup = true;
  #             app-id = "firefox$";
  #           }
  #         ];
  #       }
  #       {
  #         matches = [ { app-id = "org.wezfurlong.wezterm"; } ];
  #         open-floating = true;
  #         default-column-width = {
  #           fixed = 2000;
  #         };
  #         default-column-height = {
  #           proportion = 0.6;
  #         };
  #       }
  #       {
  #         matches = [ { is-window-cast-target = true; } ];
  #         focus-ring = {
  #           active = {
  #             color = "#f38";
  #           };
  #           inactive = {
  #             color = "#7d0";
  #           };
  #         };
  #         border = {
  #           inactive = {
  #             color = "#d2d";
  #           };
  #         };
  #       }
  #       {
  #         geometry-corner-radius = 12;
  #         clip-to-geometry = true;
  #       }
  #     ];
  #     binds = {
  #     };
  #   };
  # };
  # };

  programs = {
    cava = {
      enable = true;
    };
  };

  # services.mako = {
  #   enable = true;
  #   settings = {
  #     "actionable=true" = {
  #       anchor = "top-left";
  #     };
  #     font = "monospace 14";
  #     border-size = 1;
  #     border-radius = 20;
  #     width = 400;
  #     height = 200;
  #     max-visible = 15;
  #     layer = "overlay";
  #     anchor = "bottom-right";
  #     format = "<b>%s</b> (%a)\\n%i: %b";
  #   };
  # };
  #
  # programs.vicinae = {
  #   enable = true;
  #   systemd = {
  #     enable = true;
  #     autoStart = true;
  #   };
  #   settings = {
  #     launcher_window = {
  #       opacity = 0.85;
  #       layer_shell = {
  #         layer = "overlay";
  #       };
  #     };
  #     # theme = {
  #     #   dark = {
  #     #     name = "catppuccin-frappe";
  #     #   };
  #     #   light = {
  #     #     name = "catppuccin-latte";
  #     #   };
  #     # };
  #   };
  # };
  #
  # programs.waybar = {
  #   enable = true;
  #   systemd = {
  #     enable = true;
  #   };
  #   settings = {
  #     main = {
  #       spacing = 10;
  #       height = 15;
  #       modules-left = [
  #         "custom-logo"
  #         "niri/workspaces"
  #       ];
  #       modules-center = [
  #         "clock"
  #       ];
  #       modules-right = [
  #         "wireplumber"
  #         "memory"
  #         "cpu"
  #         "battery"
  #       ];
  #       "niri/window" = {
  #         format = "{app_id} {title}";
  #       };
  #       custom-logo = {
  #         format = "󱄅 ";
  #         tooltip = false;
  #         on-click = "vicinae toggle";
  #       };
  #     };
  #   };
  #
  #   style = ''
  #     * {
  #       border: none;
  #       font-family: "Maple Mono NF CN";
  #       font-size: 15px;
  #       min-height: 0;
  #     }
  #
  #     /* バー本体 */
  #     window#waybar {
  #       background: transparent;
  #     }
  #
  #     /* 共通モジュールデザイン */
  #     #workspaces,
  #     #window,
  #     #clock,
  #     #wireplumber,
  #     #memory,
  #     #cpu,
  #     #battery {
  #       padding: 4px 10px;
  #       margin: 6px 4px;
  #       border-radius: 10px;
  #       background-color: alpha(@base, 0.85);
  #       color: @subtext1;
  #     }
  #
  #     /* ワークスペース */
  #     #workspaces button {
  #       padding: 0 6px;
  #       border-radius: 8px;
  #       color: @subtext0;
  #     }
  #
  #     #workspaces button.focused {
  #       background: @lavender;
  #       color: @base;
  #     }
  #
  #     #workspaces button:hover {
  #       background: alpha(@surface2, 0.7);
  #     }
  #
  #     /* アクティブウィンドウ */
  #     #window {
  #       background: alpha(@sky, 0.9);
  #       color: @base;
  #       font-weight: 600;
  #     }
  #
  #     /* 時計 */
  #     #clock {
  #       background: alpha(@sapphire, 0.9);
  #       color: @base;
  #       font-weight: 600;
  #     }
  #
  #     /* ステータス系（色だけアクセント） */
  #     #wireplumber {
  #       color: @green;
  #     }
  #
  #     #memory {
  #       color: @yellow;
  #     }
  #
  #     #cpu {
  #       color: @mauve;
  #     }
  #
  #     #battery {
  #       color: @teal;
  #     }
  #   '';
  # };

  #  dconf =
  #    {
  #      true = {
  #        settings = {
  #          "org/gnome/desktop/interface" = {
  #            color-scheme = "prefer-" + theme;
  #          };
  #        };
  #      };
  #      false = { };
  #    }
  #    .${has_gui};

  # systemd = {
  #   user = {
  #     services = {
  #       awww-daemon = {
  #         Install = {
  #           WantedBy = [ "graphical-session.target" ];
  #         };
  #         Unit = {
  #           Description = "simple wallpaper manager for wayland written in rust";
  #           After = [ "graphical-session.target" ];
  #           PartOf = [ "graphical-session.target" ];
  #           Requisite = [ "graphical-session.target" ];
  #         };
  #         Service = {
  #           ExecStart = "${awww.packages.${pkgs.system}.awww}/bin/awww-daemon";
  #           Restart = "on-failure";
  #         };
  #       };
  #       awww-random = {
  #         Unit = {
  #           Description = "randomly choose wallpaper";
  #         };
  #         Service = {
  #           ExecStart = "${pkgs.nushell.out}/bin/nu --config %h/.config/nushell/config.nu -c rw";
  #         };
  #       };
  #     };
  #     timers = {
  #       awww-random = {
  #         Unit = {
  #           Description = "choose wallpaper randomly";
  #         };
  #         Timer = {
  #           OnCalendar = "*:0/5";
  #         };
  #         Install = {
  #           WantedBy = [ "graphical-session.target" ];
  #         };
  #       };
  #     };
  #   };
  # };

  catppuccin = {
    enable = true;
    autoEnable = true;
    accent = "blue";
    cursors = {
      enable = true;
      accent = "sky";
    };
    # firefox = {
    #   accent = "mauve";
    #   profiles = {
    #     dflt = {
    #       force = true;
    #     };
    #   };
    # };
    gtk = {
      icon = {
        accent = "sapphire";
      };
    };
    yazi = {
      accent = "blue";
    };
  };
}
