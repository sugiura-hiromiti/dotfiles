{
  config,
  lib,
  virtualKeyboardAdapter,
  ...
}:
let
  cfg = config.dotfiles.features.osk;
in
{
  options = {
    dotfiles = {
      features = {
        osk = {
          enable = lib.mkEnableOption "fcitx5 on-screen keyboard integration";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    i18n = {
      inputMethod = {
        fcitx5 = {
          addons = [ virtualKeyboardAdapter ];
          settings = {
            addons = {
              virtualkeyboardadapter = {
                globalSection = {
                  ActivateCmd = ''"true"'';
                  DeactivateCmd = ''"true"'';
                };
              };
            };
          };
        };
      };
    };
  };
}
