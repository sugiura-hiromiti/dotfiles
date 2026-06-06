{
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.darwin.homebrew;
in
{
  options.dotfiles.darwin.homebrew.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure baseline Homebrew packages.";
  };

  config = lib.mkIf cfg.enable {
    homebrew = {
      enable = lib.mkDefault true;

      onActivation = {
        autoUpdate = lib.mkDefault true;
        upgrade = lib.mkDefault true;
        cleanup = lib.mkDefault "zap";
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
  };
}
