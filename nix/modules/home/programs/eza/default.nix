{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.eza;
in
{
  options.dotfiles.programs.eza.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable eza.";
  };

  config = lib.mkIf cfg.enable {
    programs.eza.enable = true;
  };
}
