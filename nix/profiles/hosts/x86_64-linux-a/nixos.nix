{ lib, ... }:
{
  services = {
    hazkey = {
      enable = true;
    };
    udev = {
      extraRules = ''
        SUBSYSTEM=="iio", KERNEL=="iio:device*", ATTR{name}=="accel_3d", ENV{IIO_SENSOR_PROXY_TYPE}="iio-poll-accel"
      '';
    };
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
