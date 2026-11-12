{
  hasGui ? false,
  lib,
  ...
}:
{
  programs = {
    noctalia = lib.mkIf hasGui {
      settings = {
        bar = {
          main = {
            monitor = {
              "eDP-1" = {
                auto_hide = false;
                smart_auto_hide = false;
              };
            };
          };
        };
      };
    };
  };
  dotfiles = {
    features = {
      osk = {
        enable = lib.mkDefault hasGui;
      };
    };
    programs = {
      niri = lib.mkIf hasGui {
        absoluteInputOutput = lib.mkDefault "eDP-1";
      };
    };
  };
}
