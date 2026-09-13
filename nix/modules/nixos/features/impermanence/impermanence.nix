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
      "/nix" = {
        neededForBoot = true;
      };
      "/persist" = {
        neededForBoot = true;
      };
    };
    dotfiles = {
      features = {
        storage = {
          provisioning = {
            enable = true;
          };
        };
        ephemeralRoot = {
          enable = true;
          inherit (storage) device;
          subvolume = storage.subvolumes.root;
        };
      };
    };
  };
}
