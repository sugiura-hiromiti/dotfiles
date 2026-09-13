{ lib, config, ... }:
let
  storage = config.dotfiles.features.storage;
  cfg = storage.provisioning;
in
{
  config = lib.mkIf cfg.enable {
    disko = {
      enableConfig = false;
      devices = {
        disk = {
          main = {
            type = "disk";
            device = cfg.disk;
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  size = "512M";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                  };
                };
                system = {
                  name = storage.partitionLabel;
                  size = "100%";
                  content = {
                    type = "btrfs";
                    subvolumes = {
                      ${storage.subvolumes.root} = { };
                      ${storage.subvolumes.nix} = { };
                      ${storage.subvolumes.persist} = { };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
