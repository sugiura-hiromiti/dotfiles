{
  accounts,
  primaryAccountName,
  lib,
  pkgs,
  ...
}:
let
  accountUsers = accounts.users or { };
  accountNamesWithUid = lib.filter (name: accountUsers.${name}.uid != null) (
    lib.attrNames accountUsers
  );
  accountHomeDirectory =
    name: account:
    let
      configuredHomeDirectory = account.homeDirectory or null;
    in
    if configuredHomeDirectory != null then configuredHomeDirectory else "/Users/${name}";
in
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
      pkgs.maple-mono.NF-CN
    ];
  };
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
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
      "BarutSRB/tap/omniwm"
      # "mouseless"
    ];
    taps = [
      "BarutSRB/tap"
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
  environment = {
    shells = [
      pkgs.nushell
    ];
    systemPackages = with pkgs; [
      nushell
      tailscale
    ];
  };
  launchd.user.agents."xdg-env" = {
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = false;
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          /bin/launchctl setenv XDG_CONFIG_HOME "$HOME/.config"
          /bin/launchctl setenv XDG_DATA_HOME "$HOME/.local/share"
          /bin/launchctl setenv XDG_STATE_HOME "$HOME/.local/state"
          /bin/launchctl setenv XDG_CACHE_HOME "$HOME/.cache"
        ''
      ];
    };
  };
  users = {
    knownUsers = accountNamesWithUid;
    users = lib.listToAttrs (
      map (name: {
        inherit name;
        value = {
          uid = accountUsers.${name}.uid;
          home = lib.mkDefault (accountHomeDirectory name accountUsers.${name});
          shell = "/Users/${name}/.nix-profile/bin/nu";
        };
      }) accountNamesWithUid
    );
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
    primaryUser = primaryAccountName;
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
