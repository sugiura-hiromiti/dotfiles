{ lib, config, ... }:
let
  cfg = config.dotfiles.features.storage;
in
{
  options = {
    dotfiles = {
      features = {
        storage = {
          partitionLabel = lib.mkOption {
            type = lib.types.str;
            default = "nixos";
          };
          device = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            default = "/dev/disk/by-partlabel/${cfg.partitionLabel}";
          };
          provisioning = {
            enable = lib.mkEnableOption "provisioning";
            disk = lib.mkOption { type = lib.types.str; };
          };
          subvolumes = {
            root = lib.mkOption {
              type = lib.types.str;
              default = "@root";
            };
            persist = lib.mkOption {
              type = lib.types.str;
              default = "@persist";
            };
            nix = lib.mkOption {
              type = lib.types.str;
              default = "@nix";
            };
          };
        };
      };
    };
  };
}
