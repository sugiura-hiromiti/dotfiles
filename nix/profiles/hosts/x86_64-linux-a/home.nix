{
  programs = {
    noctalia = {
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
        enable = true;
      };
    };
    programs = {
      niri = {
        absoluteInputOutput = "eDP-1";
      };
    };
  };
}
