{ lib, ... }:
{
  dotfiles = {
    features.sessionGui = {
      enable = lib.mkDefault true;
      session = lib.mkDefault "niri";
      greeter = {
        enable = lib.mkDefault true;
        backend = lib.mkDefault "noctalia";
      };
    };
    nixos = {
      inputMethod.enable = lib.mkDefault true;
      boot.noGuiSpecialisation.enable = lib.mkDefault true;
    };
  };
}
