{ lib, pkgs, ... }:
{
  boot = {
    kernelPackages = pkgs.linuxPackages_latest.extend (
      _final: prev: {
        v4l2loopback = prev.v4l2loopback.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
              find "$out/lib/modules" \
                -mindepth 2 -maxdepth 2 \
                -type f -name 'modules.*' -delete
              '';
        });
      }
    );
  };
  services = {
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
    programs = {
      hazkey = {
        enable = true;
      };
    };
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
