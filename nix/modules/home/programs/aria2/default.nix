{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.aria2;
in
{
  options.dotfiles.programs.aria2.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable aria2.";
  };

  config = lib.mkIf cfg.enable {
    programs.aria2.enable = true;
  };
}
