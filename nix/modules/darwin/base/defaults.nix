{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.darwin.defaults;
in
{
  options.dotfiles.darwin.defaults.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline macOS defaults.";
  };

  config = lib.mkIf cfg.enable {
    system.defaults = {
      NSGlobalDomain = {
        AppleICUForce24HourTime = lib.mkDefault true;
        AppleShowAllExtensions = lib.mkDefault true;
        AppleShowAllFiles = lib.mkDefault true;
        InitialKeyRepeat = lib.mkDefault 8;
        KeyRepeat = lib.mkDefault 1;
        NSAutomaticCapitalizationEnabled = lib.mkDefault false;
        NSAutomaticDashSubstitutionEnabled = lib.mkDefault false;
        NSAutomaticPeriodSubstitutionEnabled = lib.mkDefault false;
        NSAutomaticSpellingCorrectionEnabled = lib.mkDefault false;
        NSAutomaticWindowAnimationsEnabled = lib.mkDefault false;
        NSDocumentSaveNewDocumentsToCloud = lib.mkDefault false;
        NSTableViewDefaultSizeMode = lib.mkDefault 1;
        _HIHideMenuBar = lib.mkDefault false;
        "com.apple.mouse.tapBehavior" = lib.mkDefault 1;
        # "com.apple.trackpad.scaling" = 5;
      };

      SoftwareUpdate.AutomaticallyInstallMacOSUpdates = lib.mkDefault true;

      dock = {
        autohide = lib.mkDefault true;
        mru-spaces = lib.mkDefault false;
        orientation = lib.mkDefault "right";
        static-only = lib.mkDefault true;
        tilesize = lib.mkDefault 16;
        wvous-bl-corner = lib.mkDefault 4;
        wvous-br-corner = lib.mkDefault 2;
        wvous-tl-corner = lib.mkDefault 1;
        wvous-tr-corner = lib.mkDefault 1;
      };

      # add custom pref as you like
      # CustomSystemPreferences = {};
      # CustomUserPreferences = {};
      finder = {
        FXPreferredViewStyle = lib.mkDefault "clmv";
        ShowPathbar = lib.mkDefault true;
      };

      menuExtraClock.Show24Hour = lib.mkDefault true;

      trackpad = {
        Clicking = lib.mkDefault true;
        FirstClickThreshold = lib.mkDefault 0;
        SecondClickThreshold = lib.mkDefault 0;
      };

      ".GlobalPreferences"."com.apple.mouse.scaling" = lib.mkDefault 2.0;
    };
  };
}
