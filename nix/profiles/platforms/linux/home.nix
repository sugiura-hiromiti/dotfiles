{
  pkgs,
  user,
  theme,
  has_gui,
  lib,
  ...
}:
let
  homeDir = lib.mkDefault "/home/${user}";
in
{
  home.homeDirectory = homeDir;
  home.sessionVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.so";
  programs.nushell.environmentVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.so";

  home.packages = with pkgs; [
    clang
    wl-clipboard-rs
    wf-recorder
    unixtools.xxd
    ddcutil
    evolution-data-server
  ];

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
    noctalia-shell = {
      enable = true;
      package = (pkgs.noctalia-shell.override { calendarSupport = true; });
      # colors =
      #   {
      #     dark = {
      #       mPrimary = "#cba6f7";
      #       mOnPrimary = "#11111b";
      #       mSecondary = "#fab387";
      #       mOnSecondary = "#11111b";
      #       mTertiary = "#94e2d5";
      #       mOnTertiary = "#11111b";
      #       mError = "#f38ba8";
      #       mOnError = "#11111b";
      #       mSurface = "#1e1e2e";
      #       mOnSurface = "#cdd6f4";
      #       mSurfaceVariant = "#313244";
      #       mOnSurfaceVariant = "#a3b4eb";
      #       mOutline = "#4c4f69";
      #       mShadow = "#11111b";
      #       mHover = "#94e2d5";
      #       mOnHover = "#11111b";
      #       terminal = {
      #         normal = {
      #           black = "#45475a";
      #           red = "#f38ba8";
      #           green = "#a6e3a1";
      #           yellow = "#f9e2af";
      #           blue = "#89b4fa";
      #           magenta = "#f5c2e7";
      #           cyan = "#94e2d5";
      #           white = "#a6adc8";
      #         };
      #         bright = {
      #           black = "#585b70";
      #           red = "#f37799";
      #           green = "#89d88b";
      #           yellow = "#ebd391";
      #           blue = "#74a8fc";
      #           magenta = "#f2aede";
      #           cyan = "#6bd7ca";
      #           white = "#bac2de";
      #         };
      #         foreground = "#cdd6f4";
      #         background = "#1e1e2e";
      #         selectionFg = "#cdd6f4";
      #         selectionBg = "#585b70";
      #         cursorText = "#1e1e2e";
      #         cursor = "#f5e0dc";
      #       };
      #     };
      #     light = {
      #       mPrimary = "#8839ef";
      #       mOnPrimary = "#eff1f5";
      #       mSecondary = "#fe640b";
      #       mOnSecondary = "#eff1f5";
      #       mTertiary = "#40a02b";
      #       mOnTertiary = "#eff1f5";
      #       mError = "#d20f39";
      #       mOnError = "#dce0e8";
      #       mSurface = "#eff1f5";
      #       mOnSurface = "#4c4f69";
      #       mSurfaceVariant = "#ccd0da";
      #       mOnSurfaceVariant = "#6c6f85";
      #       mOutline = "#a5adcb";
      #       mShadow = "#dce0e8";
      #       mHover = "#40a02b";
      #       mOnHover = "#eff1f5";
      #       terminal = {
      #         normal = {
      #           black = "#51576d";
      #           red = "#e78284";
      #           green = "#a6d189";
      #           yellow = "#e5c890";
      #           blue = "#8caaee";
      #           magenta = "#f4b8e4";
      #           cyan = "#81c8be";
      #           white = "#a5adce";
      #         };
      #         bright = {
      #           black = "#626880";
      #           red = "#e67172";
      #           green = "#8ec772";
      #           yellow = "#d9ba73";
      #           blue = "#7b9ef0";
      #           magenta = "#f2a4db";
      #           cyan = "#5abfb5";
      #           white = "#b5bfe2";
      #         };
      #         foreground = "#c6d0f5";
      #         background = "#303446";
      #         selectionFg = "#c6d0f5";
      #         selectionBg = "#626880";
      #         cursorText = "#303446";
      #         cursor = "#f2d5cf";
      #       };
      #     };
      #   }
      #   .${theme};
      plugins = {
        sources = [
          {
            enabled = true;
            name = "official noctalia plugins";
            url = "https://github.com/noctalia-dev/noctalia-plugins";
          }
        ];
        states = {
          keybind-cheatsheet = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
        };
        version = 2;
      };
      pluginSettings = { };
      settings = {
        bar = {
          barType = "floating";
          position = "right";
          density = "spacious";
          fontScale = 2;
          floating = true;
          useSeparateOpacity = true;
          backgroundOpacity = 0.0;
          capsureOpacity = 0.85;
          marginVertical = 10;
          marginHorizontal = 10;
          displayMode = "auto_hide";
          autoHideDelay = 600;
          autoShowDelay = 0;
          widgets = {
            left = [
              { id = "Launcher"; }
              {
                id = "Workspace";
                showApplications = true;
              }
              { id = "SystemMonitor"; }
              {
                id = "ActiveWindow";
                colorizeIcons = true;
              }
              {
                id = "MediaMini";
                showVisualizer = true;
              }
            ];
            center = [
              {
                id = "Clock";
                formatVertical = "MM dd | HH mm";
                useMonospacedFont = true;
              }
            ];
            right = [
              { id = "NotificationHistory"; }
              {
                id = "Battery";
                alwaysShowPercentage = true;
                warningThreshold = 30;
              }
              {
                id = "Volume";
              }
              { id = "Brightness"; }
              {
                id = "ControlCenter";
                useDistroLogo = true;
              }
            ];
          };
        };
        general = {
          lockScreenAnimations = true;
          enableLockScreenMediaControls = true;
          lockScreenBlur = 0.5;
        };
        wallpaper = {
          directory = (homeDir.content + "/Downloads/media/wallpapers/");
          overviewEnabled = true;
          automationEnabled = true;
          overviewTing = 0.22;
        };
        appLauncher = {
          enableClipboardHistory = true;
          autoPasteClipboard = true;
          terminalCommand = "wezterm start";
          showIconBackground = true;
          density = "comfortable";
        };
        network = {
          bluetoothRssiPollingEnabled = true;
        };
        notifications = {
          enableMarkdown = true;
          location = "bottom_left";
          backgroundOpacity = 0.5;
          saveToHistory = {
            low = false;
          };
          sounds = {
            enable = true;
            excludedApps = "";
            enableMediaToast = true;
          };
        };
        brightness = {
          enableDdcSupport = true;
        };
        colorSchemes = {
          predefinedScheme = "Catppuccin";
          schedulingMode = "location";
          darkMode = theme == "dark";
        };
      };
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

  services = {
    cliphist = {
      enable = true;
      clipboardPackage = pkgs.wl-clipboard-rs;
    };
  };
  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = "yazi.desktop";
        "text/uri-list" = "yazi.desktop";
        "video/*" = "zen-twilight.desktop";
        "image/*" = "zen-twilight.desktop";
        "audio/*" = "zen-twilight.desktop";
      };
    };
    portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-termfilechooser
        # pkgs.xdg-desktop-portal-gnome
        # pkgs.xdg-desktop-portal-gtk
      ];
      config = {
        common = {
          "org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
          # "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
          # "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        };
      };
    };
  };

  dconf =
    {
      true = {
        settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-" + theme;
          };
        };
      };
      false = { };
    }
    .${has_gui};

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
    accent = "blue";
    flavor = if theme == "dark" then "frappe" else "latte";
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
