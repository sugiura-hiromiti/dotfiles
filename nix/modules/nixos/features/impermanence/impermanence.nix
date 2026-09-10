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
        };
      };
    };

  };
  config = lib.mkIf cfg.enable {

  };
}
