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
    dotfiles = {
      features = {
        ephemeralRoot = {
          enable = true;
          inherit (storage) device;
          subvolume = storage.subvolumes.root;
        };
      };
    };
  };
}
