{
  pkgs,
  user,
  theme,
  awww,
  lib,
  ...
}:
{
  home.homeDirectory = lib.mkDefault "/home/${user}";
  home.sessionVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.so";
  programs.nushell.environmentVariables.LIBSQLITE = "${pkgs.sqlite.out}/lib/libsqlite3.so";

  home.packages = with pkgs; [
    awww.packages.${pkgs.system}.awww
    clang
    wl-clipboard-rs
    wf-recorder
    unixtools.xxd
  ];

  services.mako = {
    enable = true;
    settings = {
      "actionable=true" = {
        anchor = "top-left";
      };
      font = "monospace 14";
      border-size = 1;
      border-radius = 20;
      width = 400;
      height = 200;
      max-visible = 15;
      layer = "overlay";
      anchor = "bottom-right";
      format = "<b>%s</b> (%a)\\n%i: %b";
    };
  };

  programs.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
    };
    settings = {
      launcher_window = {
        opacity = 0.85;
        layer_shell = {
          layer = "overlay";
        };
      };
      # theme = {
      #   dark = {
      #     name = "catppuccin-frappe";
      #   };
      #   light = {
      #     name = "catppuccin-latte";
      #   };
      # };
    };
  };

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
    };
    settings = {
      main = {
        spacing = 10;
        height = 15;
        modules-left = [
          "custom-logo"
          "niri/workspaces"
        ];
        modules-center = [
          "clock"
        ];
        modules-right = [
          "wireplumber"
          "memory"
          "cpu"
          "battery"
        ];
        "niri/window" = {
          format = "{app_id} {title}";
        };
        custom-logo = {
          format = "󱄅 ";
          tooltip = false;
          on-click = "vicinae toggle";
        };
      };
    };

    style = ''
      * {
        border: none;
        font-family: "Maple Mono NF CN";
        font-size: 15px;
        min-height: 0;
      }

      /* バー本体 */
      window#waybar {
        background: transparent;
      }

      /* 共通モジュールデザイン */
      #workspaces,
      #window,
      #clock,
      #wireplumber,
      #memory,
      #cpu,
      #battery {
        padding: 4px 10px;
        margin: 6px 4px;
        border-radius: 10px;
        background-color: alpha(@base, 0.85);
        color: @subtext1;
      }

      /* ワークスペース */
      #workspaces button {
        padding: 0 6px;
        border-radius: 8px;
        color: @subtext0;
      }

      #workspaces button.focused {
        background: @lavender;
        color: @base;
      }

      #workspaces button:hover {
        background: alpha(@surface2, 0.7);
      }

      /* アクティブウィンドウ */
      #window {
        background: alpha(@sky, 0.9);
        color: @base;
        font-weight: 600;
      }

      /* 時計 */
      #clock {
        background: alpha(@sapphire, 0.9);
        color: @base;
        font-weight: 600;
      }

      /* ステータス系（色だけアクセント） */
      #wireplumber {
        color: @green;
      }

      #memory {
        color: @yellow;
      }

      #cpu {
        color: @mauve;
      }

      #battery {
        color: @teal;
      }
    '';
  };

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = "yazi.desktop";
        "text/uri-list" = "yazi.desktop";
        "video/*" = "firefox.desktop";
        "image/*" = "firefox.desktop";
        "audio/*" = "firefox.desktop";
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

  dconf = {
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-" + theme;
      };
    };
  };

  systemd = {
    user = {
      services = {
        awww-daemon = {
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
          Unit = {
            Description = "simple wallpaper manager for wayland written in rust";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
            Requisite = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${awww.packages.${pkgs.system}.awww}/bin/awww-daemon";
            Restart = "on-failure";
          };
        };
        awww-random = {
          Unit = {
            Description = "randomly choose wallpaper";
          };
          Service = {
            ExecStart = "${pkgs.nushell.out}/bin/nu --config %h/.config/nushell/config.nu -c rw";
          };
        };
      };
      timers = {
        awww-random = {
          Unit = {
            Description = "choose wallpaper randomly";
          };
          Timer = {
            OnCalendar = "*:0/5";
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };
      };
    };
  };

  catppuccin = {
    enable = true;
    accent = "blue";
    flavor = if theme == "dark" then "frappe" else "latte";
    cursors = {
      enable = true;
      accent = "sky";
    };
    firefox = {
      accent = "mauve";
      profiles = {
        dflt = {
          force = true;
        };
      };
    };
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
