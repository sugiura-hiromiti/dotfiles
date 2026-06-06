{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.fzf;
in
{
  options.dotfiles.programs.fzf.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable fzf.";
  };

  config = lib.mkIf cfg.enable {
    programs.fzf.enable = true;
  };
}
