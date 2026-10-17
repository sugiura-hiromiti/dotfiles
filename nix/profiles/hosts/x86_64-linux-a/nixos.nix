{ lib, ... }:
{
  dotfiles = {
    features = {
      autoRotation = {
        enable = true;
      };
    };
    nixos = {
      boot = {
        performanceTuning = {
          enable = lib.mkDefault true;
        };
      };
    };
  };
}
