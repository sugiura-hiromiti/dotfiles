{ lib, ... }:
{
  hardware = {
    facter = {
      reportPath = ./facter.json;
    };
  };
  #Temporary until Task 1 replaces this with the fixed Disko layout
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/9f65f627-94ca-48b5-8f2d-bd2221dc6707";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/F5D7-210B";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };
  swapDevices = [ { device = "/dev/disk/by-uuid/7ddf4db9-2419-4e90-91fd-aa22e48e660c"; } ];
  dotfiles = {
    nixos = {
      boot = {
        performanceTuning = {
          enable = lib.mkDefault true;
        };
      };
    };
  };
}
