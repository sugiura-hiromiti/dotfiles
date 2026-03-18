{
  user,
  pkgs,
  config,
  lib,
  ...
}:
let
  mypkgs = import ../pkg {
    inherit pkgs;
  };
  dotfilesRoot = "${config.home.homeDirectory}/dotfiles";
  configDirs = [
    "alacritty"
    "fcitx5"
    "fish"
    "geonkick"
    "ghostty"
    "ironbar"
    "kitty"
    "libskk"
    "niri"
    "nvim"
    "wezterm"
  ];
in
{
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };
  home = {
    shell = {
      enableNushellIntegration = true;
    };
    username = user;
    stateVersion = "26.05";
    sessionVariables = {
      CLAP_PATH = "~/.nix-profile/lib/clap";
      XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
      XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
      XDG_STATE_HOME = "${config.home.homeDirectory}/.local/state";
      XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
      SHELL = "${pkgs.nushell}/bin/nu";
    };
    packages = mypkgs;
    file = {
      ".npmrc" = {
        target = ".npmrc";
        source = ../../.npmrc;
      };
      "ssh" = {
        target = ".ssh/config";
        source = ../../.ssh/config;
      };
      "dprint" = {
        target = ".config/dprint/dprint.jsonc";
        source = ../../.dprint.jsonc;
      };
      "stylua" = {
        target = ".config/.stylua.toml";
        source = ../../.stylua.toml;
      };
    };
  };
  xdg = {
    enable = true;
    configFile = lib.genAttrs configDirs (name: {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/${name}";
    });
  };
  programs = {
    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
    aria2 = {
      enable = true;
    };
    # https://ghostty.org/docs/help/gtk-opengl-context
    #   ghostty = {
    #     enable = true;
    #     systemd = {
    #       enable = true;
    #     };
    #     clearDefaultKeybinds = true;
    #     settings = {
    #       font-family = "PlemolJP Console NF Medium";
    #       font-family-bold = "PlemolJP Console NF";
    #       font-family-italic = "PlemolJP Console NF Italic Light";
    #       font-family-bold-italic = "PlemolJP Console NF Italic";
    #       font-size = 16;
    #       background-opacity = 0.80;
    #       background-blur = 50;
    #       adjust-cell-width = -1;
    #       adjust-cell-height = -1;
    #       unfocused-split-fill = "#000000";
    #       cursor-color = "cell-foreground";
    #       cursor-text = "cell-background";
    #       mouse-hide-while-typing = true;
    #       custom-shader = "~/.config/ghostty/shaders/cursor.glsl";
    #       keybind = [
    #         "ctrl+tab=csi:9;5u"
    #         "ctrl+shift+tab=csi:9;6u"
    #         "global:f13=toggle_quick_terminal"
    #       ];
    #       window-padding-x = 0;
    #       window-padding-y = 0;
    #       focus-follows-mouse = true;
    #       gtk-quick-terminal-layer = "overlay";
    #       gtk-quick-terminal-namespace = "my_ghostty_quick_terminal";
    #       # window-colorspace = "display-p3";
    #     };
    #   };
    jujutsu = {
      enable = true;
      settings = {
        ui = {
          editor = "nvim";
        };
        user = {
          name = "sugiura-hiromiti";
          email = "pishadon57@gmail.com";
        };
      };
    };
    fd = {
      enable = true;
    };
    eza = {
      enable = true;
      # enableNushellIntegration = true;
    };
    codex = {
      enable = true;
      custom-instructions = ''
        if command execution failed and repository contains flake.nix at root, retry with nix's devshell or execute via `direnv exec`.
        use serena if possible.
      '';
      settings = {
        model = "gpt-5.4";
        model_reasoning_effort = "xhigh";
        hide_agent_reasoning = true;
        network_access = true;
        features = {
          web_search_rrequests = true;
        };
        tui = {
          notifications = true;
        };
        mcp_servers = {
          serena = {
            command = "uvx";
            args = [
              "--from"
              "git+https://github.com/oraios/serena"
              "serena"
              "start-mcp-server"
              "--context"
              "codex"
            ];
          };
          github = {
            url = "https://api.githubcopilot.com/mcp";
            bearer_token_env_var = "GITHUB_PAT_TOKEN";
          };
        };
      };
    };
    bottom = {
      enable = true;
      settings = {
        flags = {
          battery = true;
        };
      };
    };
    nh = {
      enable = true;
    };
    fzf = {
      enable = true;
    };
    direnv = {
      enable = true;
      nix-direnv = {
        enable = true;
      };
      enableNushellIntegration = true;
    };
    #bat = {
    #  enable = true;
    #};
    starship = {
      enable = true;
      settings = {
        battery = {
          display = [
            { threshold = 20; }
          ];
        };
      };
      enableNushellIntegration = true;
    };
    ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
        "-."
        "-L"
      ];
    };
    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
        color_labels = "enabled";
      };
    };
    git = {
      enable = true;
      settings = {
        core = {
          editor = "nvim";
        };
        init = {
          defaultBranch = "main";
        };
        pull = {
          rebase = false;
          ff = "only";
        };
        user = {
          name = "sugiura-hiromiti";
          email = "pishadon57@gmail.com";
        };
      };
      includes = [ { path = "~/.github_auth"; } ];
      ignores = [
        ".direnv/"
        ".serena/"
        ".DS_Store"
        "dist-newstyle/"
      ];
    };
    nushell = {
      enable = true;
      plugins = with pkgs.nushellPlugins; [
        # dbus
        # skim
        # polars
        # semver
        # formats
        # highlight
        #desktop_notifications
      ];
      environmentVariables = {
        CLAP_PATH = "~/.nix-profile/lib/clap";
      };
      configFile = {
        source = ./nushell/config.nu;
      };
    };
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
    # fuzzel =
    #   if pkgs.stdenv.isLinux then
    #     {
    #       enable = true;
    #       settings = {
    #         main = {
    #           width = 80;
    #           terminal = "${pkgs.kitty}/bin/kitty -- {cmd}";
    #           # terminal = "${pkgs.ghostty}/bin/ghostty";
    #         };
    #         key-bindings = {
    #           prev = "Shift+Tab";
    #           prev-with-wrap = "Up";
    #           next = "Tab";
    #           next-with-wrap = "Down";
    #         };
    #       };
    #     }
    #   else
    #     { };
    cargo = {
      enable = true;
      package = null;
      settings = {
        net = {
          git-fetch-with-cli = true;
        };
      };
    };
    lazygit = {
      enableNushellIntegration = true;
      enable = true;
      shellWrapperName = "lg";
      settings = { };
    };
    yazi = {
      enable = true;
      enableNushellIntegration = true;
      plugins = with pkgs.yaziPlugins; {
        inherit git;
        # inherit lazygit;
        inherit chmod;
        inherit yatline;
      };
      settings = builtins.fromTOML (builtins.readFile ./yazi/yazi.toml);
      keymap = builtins.fromTOML (builtins.readFile ./yazi/keymap.toml);
      initLua = ./yazi/init.lua;
    };
    firefox = {
      enable = true;
      profiles = {
        dflt = {
          isDefault = true;
          extensions = {
            force = true;
          };
          settings = {
            "browser.startup.homepage" = "https://www.google.com";
            "browser.toolbars.bookmarks.visibility" = "never";
            "browser.bookmarks.restore_default_bookmarks" = false;
            "browser.bookmarks.showMobileBookmarks" = false;
            "browser.crashReports.unsubmittedCheck.autoSubmit2" = true;
            "browser.search.region" = "US";
            "browser.toolbarbuttons.introduced.sidebar-button" = false;
            "sidebar.main.tools" = "syncedtabs,bookmarks,passwords";
            "sidebar.verticalTabs" = false;
            "sidebar.visibility" = "hide-sidebar";
            "widget.use-xdg-desktop-portal.file-picker" = 1;
            "widget.use-xdg-desktop-portal.mime-handler" = 1;
            "widget.use-xdg-desktop-portal.settings" = 1;
            "widget.use-xdg-desktop-portal.open-url" = 1;
          };
        };
      };
    };

  };

}
