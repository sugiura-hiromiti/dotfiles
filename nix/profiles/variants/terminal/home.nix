{ lib, pkgs, ... }:
{
  dotfiles = {
    features = {
      terminal = {
        enable = true;
        provider = "kitty";
      };
    };
  };
}
