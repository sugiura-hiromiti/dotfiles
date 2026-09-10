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
                ESP = { };
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
