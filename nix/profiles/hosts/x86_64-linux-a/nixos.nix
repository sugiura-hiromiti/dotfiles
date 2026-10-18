{ lib, ... }:
{
  services = {
    iio-niri = {
      extraArgs = [
        "--monitor"
        "eDP-1"
      ];
    };
  };
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
