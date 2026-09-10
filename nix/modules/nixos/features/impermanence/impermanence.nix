{ lib, config, ... }:
let
  cfg = config.dotfiles.features.impermanence;
in
{
  options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
  config = lib.mkIf cfg.enable {
    dotfiles = {
      features = {
        impermanence = { };
      };
    };
  };
}
