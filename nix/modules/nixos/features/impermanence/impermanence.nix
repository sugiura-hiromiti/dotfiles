{ lib, config, ... }:
let
  cfg = config.dotfiles.features.impermanence;
in
{
  options = {
    dotfiles = {
      features = {
        impermanence = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          device = lib.mkOption { type = lib.types.str; };
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
  config = lib.mkIf cfg.enable {

  };
}
