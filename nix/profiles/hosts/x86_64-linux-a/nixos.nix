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
  dotfiles = {
    programs = {
      hazkey = {
        enable = true;
      };
    };
    features = {
      autoRotation = {
        enable = true;
        monitor = "eDP-1";
        pollingSensorName = "accel_3d";
      };
      osk = {
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
