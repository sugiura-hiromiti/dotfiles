{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.nh;
in
{
  options.dotfiles.programs.nh.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable nh.";
  };

  config = lib.mkIf cfg.enable {
    programs.nh.enable = true;
  };
}
