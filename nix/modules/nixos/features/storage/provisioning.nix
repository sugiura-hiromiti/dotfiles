{ disko }:
{ lib, config, ... }:
let
  storage = config.dotfiles.features.storage;
  cfg = storage.provisioning;
in
{
  imports = [
    ./default.nix
    disko.nixosModules.disko
  ];

  options.dotfiles.features.storage = {
    partitionLabel = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
    };

    provisioning = {
      enable = lib.mkEnableOption "provisioning";

      disk = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    disko = {
      enableConfig = true;

      devices.disk.main = {
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
              label = storage.partitionLabel;
              size = "100%";

              content = {
                type = "btrfs";

                extraArgs = [
                  "-U"
                  storage.filesystemUuid
                ];

                subvolumes = {
                  ${storage.subvolumes.root}.mountpoint = "/";
                  ${storage.subvolumes.nix}.mountpoint = "/nix";
                  ${storage.subvolumes.persist}.mountpoint = "/persist";
                };
              };
            };
          };
        };
      };
    };
  };
}
