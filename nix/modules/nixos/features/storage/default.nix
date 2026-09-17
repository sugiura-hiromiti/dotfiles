{ lib, config, ... }:
let
  cfg = config.dotfiles.features.storage;
in
{
  options = {
    dotfiles = {
      features = {
        storage = {
          filesystemUuid = lib.mkOption {
            type = lib.types.str;
            description = "UUID or the Btrfs filesystem";
          };
          device = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            default = "/dev/disk/by-uuid/${cfg.filesystemUuid}";
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
