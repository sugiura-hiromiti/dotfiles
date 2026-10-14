{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.nixos.inputMethod;
in
{
  options.dotfiles.nixos.inputMethod.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure the baseline fcitx5 input method.";
  };

  config = lib.mkIf cfg.enable {
    i18n.inputMethod = {
      enable = lib.mkDefault true;
      type = lib.mkDefault "fcitx5";
      fcitx5 = {
        waylandFrontend = lib.mkDefault true;
        addons = with pkgs; [
          fcitx5-skk
          fcitx5-gtk
        ];
        settings = {
          inputMethod = {
            GroupOrder = {
              "0" = "Default";
            };
            "Groups/0" = {
              Name = "Default";
              "Default Layout" = "us";
              DefaultIM = "skk";
            };
            "Groups/0/Items/0" = {
              Name = "keyboard-us";
            };
            "Groups/0/Items/1" = {
              Name = "skk";
            };
          };
          globalOptions = {
            "Hotkey/TriggerKeys" = {
              "0" = "Control+space";
            };
          };
        };
      };
    };
  };
}
