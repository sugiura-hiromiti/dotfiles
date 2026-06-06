{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.translate-shell;
in
{
  options.dotfiles.programs.translate-shell.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to enable translate-shell.";
  };

  config = lib.mkIf cfg.enable {
    programs.translate-shell.enable = true;
  };
}
