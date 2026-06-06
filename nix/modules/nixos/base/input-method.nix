{
  config,
  lib,
  pkgs,
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
          fcitx5-mozc-ut
          fcitx5-gtk
        ];
      };
    };
  };
}
