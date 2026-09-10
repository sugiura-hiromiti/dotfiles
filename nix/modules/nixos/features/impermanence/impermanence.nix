{ lib, config, ... }:
let
  cfg = config.dotfiles.features.impermanence;
  storage = config.dotfiles.features.storage;
in
{
  imports = [
    ./ephemeral-root.nix
    ../storage
  ];
  options = {
    dotfiles = {
      features = {
        impermanence = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    fileSystems = {
      "/" = {
        device = storage.device;
        fsType = "btrfs";
        options = [ "subvol=${storage.subvolumes.root}" ];
      };
      "/persist" = {
        device = storage.device;
        fsType = "btrfs";
        options = [ "subvol=${storage.subvolumes.persist}" ];
        neededForBoot = true;
      };
      "/nix" = {
        device = storage.device;
        fsType = "btrfs";
        options = [ "subvol=${storage.subvolumes.nix}" ];
        neededForBoot = true;
      };
    };
    dotfiles = {
      features = {
        ephemeralRoot = {
          enable = true;
          device = storage.device;
          subvolume = storage.subvolumes.root;
        };
      };
    };
  };
}
