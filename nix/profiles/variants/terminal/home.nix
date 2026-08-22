{ lib, ... }:
{
  dotfiles = {
    features = {
      terminal = {
        enable = true;
        provider = lib.mkDefault "kitty";
      };
    };
  };
}
