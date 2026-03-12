{
  user,
  uid ? null,
  lib,
  pkgs,
  ...
}:
{
  security = {
    pam = {
      services = {
        sudo_local = {
          enable = true;
          touchIdAuth = true;
          watchIdAuth = true;
        };
      };
    };
  };
  fonts = {
    packages = [
      pkgs.plemoljp-nf
    ];
  };
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
    };
    brews = [
      # "FelixKratz/formulae/sketchybar"
      # {
      #   name = "koekeishiya/formulae/yabai";
      #   args = [ "HEAD" ];
      # }
      # "koekeishiya/formulae/yabai"
      # "koekeishiya/formulae/skhd"
      # "sqlite"
      # "acsandmann/tap/rift"
    ];
    casks = [
      # "karabiner-elements"
      "raycast"
      # "the-unarchiver"
      # "betterdisplay"
      "homerow"
      "docker-desktop"
      # "mouseless"
    ];
    taps = [
      # "koekeishiya/formulae"
      # "FelixKratz/formulae"
      # "acsandmann/tap"
    ];
    masApps = {
      # "Wallpaper Play" = 1638457121;
      # "Logic Pro" = 634148309;
      # "Final Cut Pro" = 424389933;
      # "Vimlike" = 1584519802;
      # "AdBlock Pro for Safari" = 1018301773;
      # "Dark Reader for Safari" = 1438243180;
    };
  };
  nix = {
    enable = false;
  };
  services = {
    tailscale = {
      enable = true;
    };
    openssh = {
      enable = true;
    };
  };
  system = {
    activationScripts = {
      pmset = {
        text = ''
          /usr/bin/pmset -a womp 1
          /usr/bin/pmset -a powernap 1
        '';
      };
    };
  };
  environment = {
    shells = [
      pkgs.nushell
    ];
    systemPackages = with pkgs; [
      nushell
      tailscale
    ];
    variables = {
      XDG_CONFIG_HOME = "/Users/${user}/.config";
      XDG_DATA_HOME = "/Users/${user}/.local/share";
      XDG_STATE_HOME = "/Users/${user}/.local/state";
      XDG_CACHE_HOME = "/Users/${user}/.cache";
    };
  };
  launchd.user.envVariables = {
    XDG_CONFIG_HOME = "/Users/${user}/.config";
    XDG_DATA_HOME = "/Users/${user}/.local/share";
    XDG_STATE_HOME = "/Users/${user}/.local/state";
    XDG_CACHE_HOME = "/Users/${user}/.cache";
  };
  launchd.user.agents."xdg-env" = {
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = false;
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          /bin/launchctl setenv XDG_CONFIG_HOME "/Users/${user}/.config"
          /bin/launchctl setenv XDG_DATA_HOME "/Users/${user}/.local/share"
          /bin/launchctl setenv XDG_STATE_HOME "/Users/${user}/.local/state"
          /bin/launchctl setenv XDG_CACHE_HOME "/Users/${user}/.cache"
        ''
      ];
    };
  };
  users = {
    knownUsers = lib.optionals (uid != null) [ user ];
    users = lib.optionalAttrs (uid != null) {
      ${user} = {
        uid = uid;
        home = lib.mkDefault "/Users/${user}";
        shell = "/Users/${user}/.nix-profile/bin/nu";
      };
    };
  };
  system = {
    primaryUser = user;
    stateVersion = 6;
    defaults = {
      NSGlobalDomain = {
        AppleICUForce24HourTime = true;
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        InitialKeyRepeat = 8;
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        NSDocumentSaveNewDocumentsToCloud = false;
        NSTableViewDefaultSizeMode = 1;
        _HIHideMenuBar = false;
        "com.apple.mouse.tapBehavior" = 1;
        # "com.apple.trackpad.scaling" = 5;

      };
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = true;
      };
      dock = {
        autohide = true;
        mru-spaces = false;
        orientation = "right";
        static-only = true;
        tilesize = 16;
        wvous-bl-corner = 4;
        wvous-br-corner = 2;
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
      };
      # add custom pref as you like
      # CustomSystemPreferences = {};
      # CustomUserPreferences = {};
      finder = {
        FXPreferredViewStyle = "clmv";
        ShowPathbar = true;
      };
      menuExtraClock = {
        Show24Hour = true;
      };
      trackpad = {
        Clicking = true;
        FirstClickThreshold = 0;
        SecondClickThreshold = 0;
      };
      ".GlobalPreferences" = {
        "com.apple.mouse.scaling" = 2.0;
      };
    };
  };
}
