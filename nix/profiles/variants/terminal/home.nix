{ lib, pkgs, ... }:
let
  kitty = lib.getExe pkgs.kitty;
in
{
  dotfiles = {
    features = {
      terminal = {
        enable = true;
        provider = "kitty";
      };
    };
    desktopIntegration = {
      termfilechoser = {
        terminal = {
          command = kitty;
        };
      };
    };
  };
}
