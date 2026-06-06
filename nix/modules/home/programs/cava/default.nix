{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.programs.cava;
in
{
  options.dotfiles.programs.cava.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable CAVA.";
  };

  config = lib.mkIf cfg.enable {
    programs.cava.enable = true;
  };
}
