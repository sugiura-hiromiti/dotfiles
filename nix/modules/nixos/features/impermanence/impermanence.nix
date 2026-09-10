{ lib, config, ... }:
let
  cfg = config.dotfiles.features.impermanence;
in
{
  imports = [ ./ephemeral-root.nix ];
  options = {
    dotfiles = {
      features = {
        impermanence = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          device = lib.mkOption { type = lib.types.str; };
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    fileSystems = {
      "/" = {
        device = cfg.device;
        fsType = "btrfs";
        options = [ "subvol=${cfg.subvolumes.root}" ];
      };
      "/persist" = {
        device = cfg.device;
        fsType = "btrfs";
        options = [ "subvol=${cfg.subvolumes.persist}" ];
        neededForBoot = true;
      };
      "/nix" = {
        device = cfg.device;
        fsType = "btrfs";
        options = [ "subvol=${cfg.subvolumes.nix}" ];
        neededForBoot = true;
      };
    };
    dotfiles = {
      features = {
        ephemeralRoot = {
          enable = true;
          device = cfg.device;
          subvolume = cfg.subvolumes.root;
        };
      };
    };
  };
}
